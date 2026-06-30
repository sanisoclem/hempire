module Hempire.Interpreter.Cache.Mock (
  runCacheMock,
) where

import Control.Concurrent.STM (TVar, atomically, modifyTVar', readTVarIO)
import Data.ByteString (ByteString)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Effectful
import Effectful.Dispatch.Dynamic
import Hempire.Effect.Cache (Cache (..))

runCacheMock :: (IOE :> es) => TVar (Map Text ByteString) -> Eff (Cache : es) a -> Eff es a
runCacheMock store = interpret $ \_env -> \case
  GetCached key ->
    liftIO $ Map.lookup key <$> readTVarIO store
  SetCached key val _ttl ->
    liftIO $ atomically $ modifyTVar' store (Map.insert key val)
  InvalidateCache key ->
    liftIO $ atomically $ modifyTVar' store (Map.delete key)
