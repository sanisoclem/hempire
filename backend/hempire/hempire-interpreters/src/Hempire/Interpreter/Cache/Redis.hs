module Hempire.Interpreter.Cache.Redis (
  runCacheRedis,
) where

import Data.Text.Encoding (encodeUtf8)
import Database.Redis qualified as R
import Effectful
import Effectful.Dispatch.Dynamic
import Hempire.Effect.Cache (Cache (..))

runCacheRedis :: (IOE :> es) => R.Connection -> Eff (Cache : es) a -> Eff es a
runCacheRedis conn = interpret $ \_env -> \case
  GetCached key ->
    liftIO $ R.runRedis conn $ do
      result <- R.get (encodeUtf8 key)
      pure $ case result of
        Right (Just v) -> Just v
        _ -> Nothing
  SetCached key val ttl ->
    liftIO $ R.runRedis conn $ do
      _ <- R.setex (encodeUtf8 key) (fromIntegral ttl) val
      pure ()
  InvalidateCache key ->
    liftIO $ R.runRedis conn $ do
      _ <- R.del [encodeUtf8 key]
      pure ()
