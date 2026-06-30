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
import Data.Text (Text)
import Effectful
import Effectful.Error.Static (Error, throwError)
import Hempire.Effect.CustomerContext (CustomerContext)
import Hempire.Effect.Events (Events, TopicName, publishEvent)
import Hempire.Effect.IdGen (IdGen, deriveId, newId)
import Hempire.Effect.Logging (Logging)
import Hempire.Effect.Time (Time, getUtcTimestampNow)
import Hempire.Identity (formatIdentityId)
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

crmEventsTopic :: TopicName
crmEventsTopic = "crm.events"

onboardCustomer ::
  (CrmEffect es, Idp :> es) =>
  OnboardCustomer ->
  Eff es OnboardResponse
onboardCustomer cmd = do
  let issuer = cmd ^. #identity % #identityIssuer
      identId = cmd ^. #identity % #identitySub
      iid = cmd ^. #inviteId
      identityId = formatIdentityId (cmd ^. #identity)
  cfg <- ensureIdpExists issuer
  ensureIdpEnabled issuer cfg
  invite <- requireInvite iid
  ensureInviteActive iid invite
  cid :: CustomerId <- deriveId iid
  userInfo <- getUserInfo (idpType cfg) identId
  let friendlyName = idpUserEmail userInfo

  alreadyExists <- customerExists cid
  unless alreadyExists $ do
    now <- getUtcTimestampNow
    createCustomerRecord cid now
    createUserRecord cid friendlyName identityId now
    claimInvite iid cid
    publishEvent crmEventsTopic $
      CrmCustomerOnboarded
        CustomerOnboarded{customerId = cid, inviteId = iid, friendlyName, identityId, at = now}

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
  publishEvent crmEventsTopic $
    CrmInviteCreated InviteCreated{inviteId = iid, source = cmd ^. #source, at = now}
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
  publishEvent crmEventsTopic $
    CrmInviteDeleted InviteDeleted{inviteId = iid, at = now}

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
  publishEvent crmEventsTopic $
    CrmCustomerStatusChanged CustomerStatusChanged{customerId = cid, active = False, at = now}

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
