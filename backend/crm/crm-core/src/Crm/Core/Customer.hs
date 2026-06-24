module Crm.Core.Customer
  ( -- * Effect constraint alias
    CrmEffect
    -- * Operations
  , onboardCustomer
  , createInvite
  , deleteCustomerInvite
  , getCustomerInvite
  , deactivateCustomer
  ) where

import Control.Monad (unless)
import Control.Monad.Trans.Class (lift)
import Control.Monad.Trans.Except (ExceptT, runExceptT, throwE)
import Crm.Core.CustomerContext (CustomerContext)
import Crm.Core.Domain (CrmDomainError (..))
import Crm.Core.Idp (Idp, setIdentityCustomer)
import Crm.Core.Repository
import Crm.Types hiding (InviteAlreadyClaimed)
import Data.Aeson (toJSON)
import Effectful
import Hempire.DomainId (DomainId (..), showId)
import Hempire.Effect.Events (Events, publishEvent)
import Hempire.Effect.IdGen (IdGen, deriveId, newId)
import Hempire.Effect.Logging (Logging, logInfo)
import Hempire.Effect.Time (Time, getUtcTimestampNow)
import Optics.Core

type CrmEffect es =
  ( CrmRepository   :> es
  , CustomerContext :> es
  , Idp             :> es
  , IdGen           :> es
  , Time            :> es
  , Events          :> es
  , Logging         :> es
  )

type Crm es = ExceptT CrmDomainError (Eff es)

onboardCustomer
  :: CrmEffect es
  => OnboardCustomer
  -> Eff es (Either CrmDomainError CustomerId)
onboardCustomer cmd = runExceptT $ do
  let idpId   = cmd ^. #identity % #providerId
      identId = cmd ^. #identity % #identityId
      iid     = cmd ^. #inviteId
  cfg    <- ensureIdpExists idpId
  ensureIdpEnabled idpId cfg
  invite <- requireInvite iid
  ensureInviteActive iid invite
  rawCid <- lift (deriveId (getRaw iid))
  let cid = wrapRaw rawCid :: CustomerId
  alreadyExists <- lift (customerExists cid)
  unless alreadyExists $ do
    now <- lift getUtcTimestampNow
    lift $ createCustomerRecord cid now
    lift $ claimInvite iid cid
    lift $ publishEvent "crm.events"
      CustomerOnboarded{customerId = cid, inviteId = iid, at = now}
    lift $ logInfo "crm.customer.onboarded"
      [("customerId", toJSON (showId cid)), ("inviteId", toJSON (showId iid))]
  lift $ setIdentityCustomer (idpType cfg) identId cid
  pure cid

createInvite
  :: CrmEffect es
  => CreateInvite
  -> Eff es (Either CrmDomainError InviteId)
createInvite cmd = do
  now <- getUtcTimestampNow
  raw <- newId
  let iid = wrapRaw raw :: InviteId
  createInviteRecord iid (cmd ^. #source) now (cmd ^. #comment)
  publishEvent "crm.events"
    InviteCreated
      { inviteId = iid
      , source   = cmd ^. #source
      , at       = now
      }
  logInfo "crm.invite.created"
    [("inviteId", toJSON (showId iid)), ("source", toJSON (cmd ^. #source))]
  pure (Right iid)

deleteCustomerInvite
  :: CrmEffect es
  => InviteId
  -> Eff es (Either CrmDomainError ())
deleteCustomerInvite iid = runExceptT $ do
  invite <- requireInvite iid
  ensureInviteUnclaimed iid invite
  now <- lift getUtcTimestampNow
  lift $ deleteInviteRecord iid
  lift $ publishEvent "crm.events" InviteDeleted{inviteId = iid, at = now}
  lift $ logInfo "crm.invite.deleted" [("inviteId", toJSON (showId iid))]

getCustomerInvite
  :: CrmEffect es
  => InviteId
  -> Eff es (Either CrmDomainError InviteDetails)
getCustomerInvite iid =
  maybe (Left (InviteNotFound iid)) Right <$> findInvite iid

deactivateCustomer
  :: CrmEffect es
  => CustomerId
  -> Eff es (Either CrmDomainError ())
deactivateCustomer cid = runExceptT $ do
  ensureCustomerExists cid
  now <- lift getUtcTimestampNow
  lift $ setCustomerActive cid False now
  lift $ publishEvent "crm.events" CustomerDeactivated{customerId = cid, at = now}
  lift $ logInfo "crm.customer.deactivated" [("customerId", toJSON (showId cid))]

-- ---------------------------------------------------------------------------
-- Private guard helpers
-- ---------------------------------------------------------------------------

ensureIdpExists :: CrmRepository :> es => IdentityProviderId -> Crm es IdpConfig
ensureIdpExists idpId =
  lift (getIdpConfig idpId) >>= maybe (throwE (IdpNotFound idpId)) pure

ensureIdpEnabled :: IdentityProviderId -> IdpConfig -> Crm es ()
ensureIdpEnabled idpId cfg =
  unless (idpEnabled cfg) $ throwE (IdpNotEnabledForCustomers idpId)

requireInvite :: CrmRepository :> es => InviteId -> Crm es InviteDetails
requireInvite iid =
  lift (findInvite iid) >>= maybe (throwE (InviteNotFound iid)) pure

ensureInviteActive :: InviteId -> InviteDetails -> Crm es ()
ensureInviteActive iid inv =
  unless (inv ^. #active) $ throwE (InviteNotActive iid)

ensureInviteUnclaimed :: InviteId -> InviteDetails -> Crm es ()
ensureInviteUnclaimed iid inv = case inv ^. #customerId of
  Just _  -> throwE (InviteAlreadyClaimed iid)
  Nothing -> pure ()

ensureCustomerExists :: CrmRepository :> es => CustomerId -> Crm es ()
ensureCustomerExists cid = do
  exists <- lift (customerExists cid)
  unless exists $ throwE (CustomerNotFound cid)
