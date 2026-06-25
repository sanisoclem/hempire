module Hempire.Effect.CustomerContext (
  CustomerContext (..),
  getCustomerId,
) where

import Effectful
import Effectful.TH (makeEffect)
import Hempire.Id (CustomerId)

data CustomerContext :: Effect where
  GetCustomerId :: CustomerContext m (Maybe CustomerId)

type instance DispatchOf CustomerContext = Dynamic

makeEffect ''CustomerContext
