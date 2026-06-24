module Crm.Core.Customer
  ( -- * Effect constraint alias
    CrmEffect
    -- * Operations
  , onboardCustomer
  , createInvite
  , deleteCustomerInvite
  , getCustomerInvite
  , getOnboardingStatus
  , deactivateCustomer
  ) where

import Control.Monad (unless)
import Control.Monad.Trans.Class (lift)
import Control.Monad.Trans.Except (ExceptT, runExceptT, throwE)
import Crm.Core.CustomerContext (CustomerContext)
import Crm.Core.Domain (CrmDomainError (..))
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
  , IdGen           :> es
  , Time            :> es
  , Events          :> es
  , Logging         :> es
  )

onboardCustomer
  :: CrmEffect es
  => OnboardCustomer
  -> Eff es (Either CrmDomainError CustomerId)
onboardCustomer cmd = runExceptT $ do
  let idpId   = cmd ^. #identity % #providerId
      identId = cmd ^. #identity % #identityId
      iid     = cmd ^. #inviteId
  ensureIdpEnabled idpId
  invite <- requireInvite iid
  ensureInviteActive iid invite
  ensureInviteUnclaimed iid invite
  now    <- lift getUtcTimestampNow
  rawCid <- lift (deriveId (getRaw iid))
  let cid = wrapRaw rawCid :: CustomerId
  lift $ createCustomerRecord cid now
  lift $ createIdentityRecord idpId identId cid
  lift $ claimInvite iid cid
  lift $ publishEvent "crm.events"
    CustomerOnboarded
      { customerId = cid
      , inviteId   = iid
      , identity   = cmd ^. #identity
      , at         = now
      }
  lift $ logInfo "crm.customer.onboarded"
    [("customerId", toJSON (showId cid)), ("inviteId", toJSON (showId iid))]
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

getOnboardingStatus
  :: CrmEffect es
  => Identity
  -> Eff es OnboardingStatus
getOnboardingStatus ident = do
  mCid <- findCustomerByIdentity (ident ^. #providerId) (ident ^. #identityId)
  pure $ maybe NotOnboarded Onboarded mCid

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

type Crm es = ExceptT CrmDomainError (Eff es)

ensureIdpEnabled :: CrmRepository :> es => IdentityProviderId -> Crm es ()
ensureIdpEnabled idpId = do
  enabled <- lift (isIdpEnabledForCustomers idpId)
  unless enabled $ throwE (IdpNotEnabledForCustomers idpId)

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
