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

import Crm.Core.Domain (CrmDomainError (..))
import Crm.Core.Repository
import Crm.Types hiding (InviteAlreadyClaimed)
import Data.Aeson (toJSON)
import Hempire.DomainId (DomainId (..), showId)
import Hempire.Effect.Events (Events, publishEvent)
import Hempire.Effect.IdGen (IdGen, deriveId, newId)
import Hempire.Effect.Logging (Logging, logInfo)
import Hempire.Effect.Time (Time, getUtcTimestampNow)
import Effectful
import Optics.Core

type CrmEffect es =
  ( CrmRepository :> es
  , IdGen         :> es
  , Time          :> es
  , Events        :> es
  , Logging       :> es
  )

onboardCustomer
  :: CrmEffect es
  => OnboardCustomer
  -> Eff es (Either CrmDomainError CustomerId)
onboardCustomer cmd = do
  let idpId      = cmd ^. #identity % #providerId
      identId    = cmd ^. #identity % #identityId
      iid        = cmd ^. #inviteId
  enabled <- isIdpEnabledForCustomers idpId
  if not enabled
    then pure (Left (IdpNotEnabledForCustomers idpId))
    else do
      mInvite <- findInvite iid
      case mInvite of
        Nothing     -> pure (Left (InviteNotFound iid))
        Just invite -> do
          if not (invite ^. #active)
            then pure (Left (InviteNotActive iid))
            else case invite ^. #customerId of
              Just _  -> pure (Left (InviteAlreadyClaimed iid))
              Nothing -> do
                now    <- getUtcTimestampNow
                rawCid <- deriveId (getRaw iid)
                let cid = wrapRaw rawCid :: CustomerId
                createCustomerRecord cid now
                createIdentityRecord idpId identId cid
                claimInvite iid cid
                publishEvent "crm.events"
                  CustomerOnboarded
                    { customerId = cid
                    , inviteId   = iid
                    , identity   = cmd ^. #identity
                    , at         = now
                    }
                logInfo "crm.customer.onboarded"
                  [("customerId", toJSON (showId cid)), ("inviteId", toJSON (showId iid))]
                pure (Right cid)

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
deleteCustomerInvite iid = do
  mInvite <- findInvite iid
  case mInvite of
    Nothing     -> pure (Left (InviteNotFound iid))
    Just invite -> case invite ^. #customerId of
      Just _  -> pure (Left (InviteAlreadyClaimed iid))
      Nothing -> do
        now <- getUtcTimestampNow
        deleteInviteRecord iid
        publishEvent "crm.events" InviteDeleted{inviteId = iid, at = now}
        logInfo "crm.invite.deleted" [("inviteId", toJSON (showId iid))]
        pure (Right ())

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
deactivateCustomer cid = do
  exists <- customerExists cid
  if not exists
    then pure (Left (CustomerNotFound cid))
    else do
      now <- getUtcTimestampNow
      setCustomerActive cid False now
      publishEvent "crm.events" CustomerDeactivated{customerId = cid, at = now}
      logInfo "crm.customer.deactivated" [("customerId", toJSON (showId cid))]
      pure (Right ())
