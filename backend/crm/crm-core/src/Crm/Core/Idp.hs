module Crm.Core.Idp (Idp (..), setIdentityCustomer) where

import Crm.Types (CustomerId)
import Data.Text (Text)
import Effectful
import Effectful.TH (makeEffect)

data Idp :: Effect where
  -- idpType (e.g. "zitadel"), identityId (sub), customerId
  SetIdentityCustomer :: Text -> Text -> CustomerId -> Idp m ()

type instance DispatchOf Idp = Dynamic

makeEffect ''Idp
