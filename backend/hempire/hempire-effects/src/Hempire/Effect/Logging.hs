module Hempire.Effect.Logging
  ( -- * Effect
    Logging (..)
    -- * Operations
  , logInfo
  , logWarn
  , logError
  , logDebug
    -- * Types
  , LogField
  ) where

import Data.Aeson (Value)
import Data.Text (Text)
import Effectful
import Effectful.Dispatch.Dynamic
import Effectful.TH (makeEffect)

type LogField = (Text, Value)

data Logging :: Effect where
  LogInfo  :: Text -> [LogField] -> Logging m ()
  LogWarn  :: Text -> [LogField] -> Logging m ()
  LogError :: Text -> [LogField] -> Logging m ()
  LogDebug :: Text -> [LogField] -> Logging m ()

type instance DispatchOf Logging = Dynamic

makeEffect ''Logging
