module Crm.Core.Idp (Idp (..), IdpUserInfo (..), setIdentityCustomer, getUserInfo) where

import Crm.Types (CustomerId)
import Data.Text (Text)
import Effectful
import Effectful.TH (makeEffect)

newtype IdpUserInfo = IdpUserInfo
  { idpUserEmail :: Text
  }

data Idp :: Effect where
  SetIdentityCustomer :: Text -> Text -> CustomerId -> Idp m ()
  GetUserInfo :: Text -> Text -> Idp m IdpUserInfo

type instance DispatchOf Idp = Dynamic

makeEffect ''Idp
