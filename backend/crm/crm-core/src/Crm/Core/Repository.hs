module Crm.Core.Repository
  ( -- * Effect
    CrmRepository (..)
    -- * Invite operations
  , findInvite
  , createInviteRecord
  , claimInvite
  , deleteInviteRecord
    -- * Customer operations
  , createCustomerRecord
  , customerExists
  , setCustomerActive
    -- * Identity operations
  , findCustomerByIdentity
  , createIdentityRecord
    -- * IdP operations
  , isIdpEnabledForCustomers
  ) where

import Crm.Types (CustomerId, IdentityProviderId, InviteDetails, InviteId, InviteSource)
import Data.Text (Text)
import Data.Time (UTCTime)
import Effectful
import Effectful.TH (makeEffect)

data CrmRepository :: Effect where
  -- Invite
  FindInvite         :: InviteId -> CrmRepository m (Maybe InviteDetails)
  CreateInviteRecord :: InviteId -> InviteSource -> UTCTime -> Maybe Text -> CrmRepository m ()
  ClaimInvite        :: InviteId -> CustomerId -> CrmRepository m ()
  DeleteInviteRecord :: InviteId -> CrmRepository m ()
  -- Customer
  CreateCustomerRecord :: CustomerId -> UTCTime -> CrmRepository m ()
  CustomerExists       :: CustomerId -> CrmRepository m Bool
  SetCustomerActive    :: CustomerId -> Bool -> UTCTime -> CrmRepository m ()
  -- Identity
  FindCustomerByIdentity :: IdentityProviderId -> Text -> CrmRepository m (Maybe CustomerId)
  CreateIdentityRecord   :: IdentityProviderId -> Text -> CustomerId -> CrmRepository m ()
  -- IdP
  IsIdpEnabledForCustomers :: IdentityProviderId -> CrmRepository m Bool

type instance DispatchOf CrmRepository = Dynamic

makeEffect ''CrmRepository
