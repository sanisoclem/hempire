module Hempire.Interpreter.Logging.FastLogger
  ( runLoggingFastLogger
  ) where

import Data.Aeson (Value, encode, object, (.=))
import Data.Aeson.Key (fromText)
import Data.ByteString.Lazy qualified as BL
import Data.Text (Text)
import Effectful
import Effectful.Dispatch.Dynamic
import System.Log.FastLogger (LoggerSet, pushLogStr, toLogStr)

import Hempire.Effect.Logging (LogField, Logging (..))

runLoggingFastLogger :: IOE :> es => LoggerSet -> Eff (Logging : es) a -> Eff es a
runLoggingFastLogger ls = interpret $ \_env -> \case
  LogInfo  msg fields -> emit ls "info"  msg fields
  LogWarn  msg fields -> emit ls "warn"  msg fields
  LogError msg fields -> emit ls "error" msg fields
  LogDebug msg fields -> emit ls "debug" msg fields

emit :: IOE :> es => LoggerSet -> Text -> Text -> [LogField] -> Eff es ()
emit ls level msg fields = liftIO $ do
  let entry :: Value = object (["level" .= level, "message" .= msg] ++ map mkField fields)
  pushLogStr ls (toLogStr (BL.toStrict (encode entry)) <> toLogStr ("\n" :: Text))
  where
    mkField (k, v) = fromText k .= v
