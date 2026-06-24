module Crm.Interpreter.CustomerContext
  ( runCustomerContext
  , runInternalContext
  ) where

import Crm.Core.CustomerContext (CustomerContext (..))
import Crm.Types (CustomerId)
import Effectful
import Effectful.Dispatch.Dynamic

-- | Run with a known customer identity (customer-facing BFF requests).
runCustomerContext :: CustomerId -> Eff (CustomerContext : es) a -> Eff es a
runCustomerContext cid = interpret $ \_env -> \case
  GetCustomerId -> pure (Just cid)

-- | Run without a customer identity (internal/admin requests).
runInternalContext :: Eff (CustomerContext : es) a -> Eff es a
runInternalContext = interpret $ \_env -> \case
  GetCustomerId -> pure Nothing
