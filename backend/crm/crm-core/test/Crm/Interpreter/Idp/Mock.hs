module Crm.Interpreter.Idp.Mock (runIdpMock) where

import Crm.Core.Idp (Idp (..))
import Effectful
import Effectful.Dispatch.Dynamic

runIdpMock :: Eff (Idp : es) a -> Eff es a
runIdpMock = interpret $ \_env -> \case
  SetIdentityCustomer {} -> pure ()
