module Crm.Core.Customer (
    CrmEffect,
    onboardCustomer,
    createInvite,
    deleteCustomerInvite,
    getCustomerInvite,
    deactivateCustomer,
) where

import Control.Monad (unless)
import Crm.Core.Domain (CrmDomainError (..))
import Crm.Core.Idp (Idp, getUserInfo, idpUserEmail, setIdentityCustomer)
import Crm.Core.Repository
import Crm.Types hiding (InviteAlreadyClaimed)
import Data.Aeson (toJSON)
import Data.Text (Text)
import Effectful
import Effectful.Error.Static (Error, throwError)
import Hempire.DomainId (showId)
import Hempire.Effect.CustomerContext (CustomerContext)
import Hempire.Effect.Events (Events, publishEvent)
import Hempire.Effect.IdGen (IdGen, deriveId, newId)
import Hempire.Effect.Logging (Logging, logInfo)
import Hempire.Effect.Time (Time, getUtcTimestampNow)
import Optics.Core

type CrmEffect es =
    ( CrmRepository :> es
    , CustomerContext :> es
    , IdGen :> es
    , Time :> es
    , Events :> es
    , Logging :> es
    , Error CrmDomainError :> es
    )

onboardCustomer ::
    (CrmEffect es, Idp :> es) =>
    OnboardCustomer ->
    Eff es OnboardResponse
onboardCustomer cmd = do
    let issuer = cmd ^. #identity % #identityIssuer
        identId = cmd ^. #identity % #identitySub
        iid = cmd ^. #inviteId
        identityId = issuer <> "|" <> identId
    cfg <- ensureIdpExists issuer
    ensureIdpEnabled issuer cfg
    invite <- requireInvite iid
    ensureInviteActive iid invite
    cid :: CustomerId <- deriveId iid
    userInfo <- getUserInfo (idpType cfg) identId
    let friendlyName = idpUserEmail userInfo

    alreadyExists <- customerExists cid
    -- this block is atomic (ambient transaction), so if the user already exists, then
    -- we know all of this was already performed
    -- we need to do this since setting the customerIdP is not atomic
    -- and could fail
    unless alreadyExists $ do
        now <- getUtcTimestampNow
        createCustomerRecord cid now
        createUserRecord cid friendlyName identityId now
        claimInvite iid cid
        publishEvent
            "crm.events"
            CustomerOnboarded{customerId = cid, inviteId = iid, friendlyName, identityId, at = now}

    -- set the customerId in the IdP
    setIdentityCustomer (idpType cfg) identId cid

    pure OnboardResponse{customerId = cid, friendlyName, identityId}

createInvite ::
    (CrmEffect es) =>
    CreateInvite ->
    Eff es InviteId
createInvite cmd = do
    now <- getUtcTimestampNow
    iid :: InviteId <- newId
    createInviteRecord iid (cmd ^. #source) now (cmd ^. #comment)
    publishEvent
        "crm.events"
        InviteCreated{inviteId = iid, source = cmd ^. #source, at = now}
    pure iid

deleteCustomerInvite ::
    (CrmEffect es) =>
    InviteId ->
    Eff es ()
deleteCustomerInvite iid = do
    invite <- requireInvite iid
    ensureInviteUnclaimed iid invite
    now <- getUtcTimestampNow
    deleteInviteRecord iid
    publishEvent "crm.events" InviteDeleted{inviteId = iid, at = now}

getCustomerInvite ::
    (CrmEffect es) =>
    InviteId ->
    Eff es InviteDetails
getCustomerInvite iid =
    findInvite iid >>= maybe (throwError (InviteNotFound iid)) pure

deactivateCustomer ::
    (CrmEffect es) =>
    CustomerId ->
    Eff es ()
deactivateCustomer cid = do
    ensureCustomerExists cid
    now <- getUtcTimestampNow
    setCustomerActive cid False now
    publishEvent
        "crm.events"
        CustomerStatusChanged{customerId = cid, active = False, at = now}

ensureIdpExists :: (CrmEffect es) => Text -> Eff es IdpConfig
ensureIdpExists issuer =
    getIdpConfig issuer >>= maybe (throwError (IdpNotFound issuer)) pure

ensureIdpEnabled :: (CrmEffect es) => Text -> IdpConfig -> Eff es ()
ensureIdpEnabled issuer cfg =
    unless (idpEnabled cfg) $ throwError (IdpNotEnabledForCustomers issuer)

requireInvite :: (CrmEffect es) => InviteId -> Eff es InviteDetails
requireInvite iid =
    findInvite iid >>= maybe (throwError (InviteNotFound iid)) pure

ensureInviteActive :: (CrmEffect es) => InviteId -> InviteDetails -> Eff es ()
ensureInviteActive iid inv =
    unless (inv ^. #active) $ throwError (InviteNotActive iid)

ensureInviteUnclaimed :: (CrmEffect es) => InviteId -> InviteDetails -> Eff es ()
ensureInviteUnclaimed iid inv = case inv ^. #customerId of
    Just _ -> throwError (InviteAlreadyClaimed iid)
    Nothing -> pure ()

ensureCustomerExists :: (CrmEffect es) => CustomerId -> Eff es ()
ensureCustomerExists cid = do
    exists <- customerExists cid
    unless exists $ throwError (CustomerNotFound cid)
