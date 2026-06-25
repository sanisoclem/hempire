module Hempire.Effect.Logging (
  Logging (..),
  logInfo,
  logWarn,
  logError,
  logDebug,
  LogField,
) where

import Data.Aeson (Value)
import Data.Text (Text)
import Effectful
import Effectful.TH (makeEffect)

type LogField = (Text, Value)

data Logging :: Effect where
  LogInfo :: Text -> [LogField] -> Logging m ()
  LogWarn :: Text -> [LogField] -> Logging m ()
  LogError :: Text -> [LogField] -> Logging m ()
  LogDebug :: Text -> [LogField] -> Logging m ()

type instance DispatchOf Logging = Dynamic

makeEffect ''Logging
