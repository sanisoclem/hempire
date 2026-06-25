module Hempire.Effect.CustomerContext
  ( CustomerContext (..)
  , getCustomerId
  ) where

import Effectful
import Effectful.TH (makeEffect)
import Hempire.Id (CustomerId)

-- | Provides the identity of the calling customer.
-- 'Nothing' indicates an internal/admin request with no customer context.
-- 'Just cid' indicates a customer-authenticated request.
data CustomerContext :: Effect where
  GetCustomerId :: CustomerContext m (Maybe CustomerId)

type instance DispatchOf CustomerContext = Dynamic

makeEffect ''CustomerContext
