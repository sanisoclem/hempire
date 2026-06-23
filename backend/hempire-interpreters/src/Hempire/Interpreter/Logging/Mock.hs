module Hempire.Interpreter.Logging.Mock
  ( runLoggingMock
  ) where

import Control.Concurrent.STM (TVar, atomically, modifyTVar)
import Data.Text (Text)
import Effectful
import Effectful.Dispatch.Dynamic

import Hempire.Effect.Logging (LogField, Logging (..))

runLoggingMock
  :: IOE :> es
  => TVar [(Text, [LogField])]
  -> Eff (Logging : es) a
  -> Eff es a
runLoggingMock captured = interpret $ \_env -> \case
  LogInfo  msg fields -> liftIO $ atomically $ modifyTVar captured (++ [(msg, fields)])
  LogWarn  msg fields -> liftIO $ atomically $ modifyTVar captured (++ [(msg, fields)])
  LogError msg fields -> liftIO $ atomically $ modifyTVar captured (++ [(msg, fields)])
  LogDebug msg fields -> liftIO $ atomically $ modifyTVar captured (++ [(msg, fields)])
