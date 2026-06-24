module Hempire.Interpreter.IdGen.Mock
  ( runIdGenMock
  ) where

import Data.Text (Text)
import Effectful
import Effectful.Dispatch.Dynamic

import Hempire.Effect.IdGen (IdGen (..))

-- | Mock IdGen interpreter for tests.
-- 'NewId' always returns @fixedId@.
-- 'DeriveId' returns @"derived_" <> input@, making expected IDs predictable
-- without needing real SHA-256.
runIdGenMock :: Text -> Eff (IdGen : es) a -> Eff es a
runIdGenMock fixedId = interpret $ \_env -> \case
  NewId      -> pure fixedId
  DeriveId t -> pure ("derived_" <> t)
