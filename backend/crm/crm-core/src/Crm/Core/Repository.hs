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
import Crm.Types.IdpType (IdpType)
import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text)
import Data.Time (UTCTime)
import Effectful
import Effectful.TH (makeEffect)
import GHC.Generics (Generic)

data IdpConfig = IdpConfig
  { idpEnabled :: Bool
  , idpType :: IdpType
  }
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

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
