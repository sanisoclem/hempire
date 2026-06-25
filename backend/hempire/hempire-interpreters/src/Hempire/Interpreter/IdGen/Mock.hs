module Hempire.Interpreter.IdGen.Mock (
  runIdGenMock,
) where

import Data.Text (Text)
import Effectful
import Effectful.Dispatch.Dynamic
import Hempire.Effect.IdGen (IdGen (..))

runIdGenMock :: Text -> Eff (IdGen : es) a -> Eff es a
runIdGenMock fixedId = interpret $ \_env -> \case
  NewIdRaw -> pure fixedId
  DeriveIdRaw t -> pure ("derived_" <> t)
