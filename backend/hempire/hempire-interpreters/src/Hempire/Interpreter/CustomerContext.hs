module Hempire.Interpreter.CustomerContext (
  runCustomerContext,
  runInternalContext,
) where

import Effectful
import Effectful.Dispatch.Dynamic
import Hempire.Effect.CustomerContext (CustomerContext (..))
import Hempire.Id (CustomerId)

runCustomerContext :: CustomerId -> Eff (CustomerContext : es) a -> Eff es a
runCustomerContext cid = interpret $ \_env -> \case
  GetCustomerId -> pure (Just cid)

runInternalContext :: Eff (CustomerContext : es) a -> Eff es a
runInternalContext = interpret $ \_env -> \case
  GetCustomerId -> pure Nothing
