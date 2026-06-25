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
import Crm.Core.Idp (Idp, setIdentityCustomer)
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
  Eff es CustomerId
onboardCustomer cmd = do
  let issuer = cmd ^. #identity % #identityIssuer
      identId = cmd ^. #identity % #identitySub
      iid = cmd ^. #inviteId
  cfg <- ensureIdpExists issuer
  ensureIdpEnabled issuer cfg
  invite <- requireInvite iid
  ensureInviteActive iid invite
  cid :: CustomerId <- deriveId iid
  alreadyExists <- customerExists cid
  unless alreadyExists $ do
    now <- getUtcTimestampNow
    createCustomerRecord cid now
    claimInvite iid cid
    publishEvent
      "crm.events"
      CustomerOnboarded {customerId = cid, inviteId = iid, at = now}
    logInfo
      "crm.customer.onboarded"
      [("customerId", toJSON (showId cid)), ("inviteId", toJSON (showId iid))]
  setIdentityCustomer (idpType cfg) identId cid
  pure cid

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
    InviteCreated {inviteId = iid, source = cmd ^. #source, at = now}
  logInfo
    "crm.invite.created"
    [("inviteId", toJSON (showId iid)), ("source", toJSON (cmd ^. #source))]
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
  publishEvent "crm.events" InviteDeleted {inviteId = iid, at = now}
  logInfo "crm.invite.deleted" [("inviteId", toJSON (showId iid))]

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
    CustomerStatusChanged {customerId = cid, active = False, at = now}
  logInfo "crm.customer.deactivated" [("customerId", toJSON (showId cid))]

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
