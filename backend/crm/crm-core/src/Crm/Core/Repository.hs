module Crm.Core.Repository
  ( -- * Effect
    CrmRepository (..)
    -- * Config types
  , IdpConfig (..)
    -- * Invite operations
  , findInvite
  , createInviteRecord
  , claimInvite
  , deleteInviteRecord
    -- * Customer operations
  , createCustomerRecord
  , customerExists
  , setCustomerActive
    -- * IdP operations
  , getIdpConfig
  ) where

import Crm.Types (CustomerId, IdentityProviderId, InviteDetails, InviteId, InviteSource)
import Data.Text (Text)
import Data.Time (UTCTime)
import Effectful
import Effectful.TH (makeEffect)

data IdpConfig = IdpConfig
  { idpEnabled :: Bool
  , idpType    :: Text
  }

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
  -- IdP
  GetIdpConfig :: IdentityProviderId -> CrmRepository m (Maybe IdpConfig)

type instance DispatchOf CrmRepository = Dynamic

makeEffect ''CrmRepository
