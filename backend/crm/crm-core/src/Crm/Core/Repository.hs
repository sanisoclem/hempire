module Crm.Core.Repository (
  CrmRepository (..),
  IdpConfig (..),
  findInvite,
  createInviteRecord,
  claimInvite,
  deleteInviteRecord,
  createCustomerRecord,
  createUserRecord,
  customerExists,
  setCustomerActive,
  getIdpConfig,
) where

import Crm.Types (CustomerId, InviteDetails, InviteId, InviteSource)
import Data.Text (Text)
import Data.Time (UTCTime)
import Effectful
import Effectful.TH (makeEffect)

data IdpConfig = IdpConfig
  { idpEnabled :: Bool
  , idpType :: Text
  }

data CrmRepository :: Effect where
  FindInvite :: InviteId -> CrmRepository m (Maybe InviteDetails)
  CreateInviteRecord :: InviteId -> InviteSource -> UTCTime -> Maybe Text -> CrmRepository m ()
  ClaimInvite :: InviteId -> CustomerId -> CrmRepository m ()
  DeleteInviteRecord :: InviteId -> CrmRepository m ()
  CreateCustomerRecord :: CustomerId -> UTCTime -> CrmRepository m ()
  CreateUserRecord :: CustomerId -> Text -> Text -> UTCTime -> CrmRepository m ()
  CustomerExists :: CustomerId -> CrmRepository m Bool
  SetCustomerActive :: CustomerId -> Bool -> UTCTime -> CrmRepository m ()
  GetIdpConfig :: Text -> CrmRepository m (Maybe IdpConfig)

type instance DispatchOf CrmRepository = Dynamic

makeEffect ''CrmRepository
