module Crm.Core.CustomerContext
  ( CustomerContext (..)
  , getCustomerId
  ) where

import Crm.Types (CustomerId)
import Effectful
import Effectful.TH (makeEffect)

-- | Provides the identity of the calling customer.
-- 'Nothing' indicates an internal/admin request with no customer context.
-- 'Just cid' indicates a customer-authenticated request.
data CustomerContext :: Effect where
  GetCustomerId :: CustomerContext m (Maybe CustomerId)

type instance DispatchOf CustomerContext = Dynamic

makeEffect ''CustomerContext
