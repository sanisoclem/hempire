module Hempire.AppEnv (
  AppEnv (..),
  newAppEnv,
) where

import Data.ByteString (ByteString)
import Data.Pool (Pool, defaultPoolConfig, newPool, setNumStripes)
import Database.PostgreSQL.Simple (Connection, close, connectPostgreSQL)
import Database.Redis qualified as R
import Hempire.Env (requireEnv)
import System.Log.FastLogger (LoggerSet, defaultBufSize, newStdoutLoggerSet)

data AppEnv = AppEnv
  { appPool :: Pool Connection
  , appLoggerSet :: LoggerSet
  , appRedis :: R.Connection
  }

newAppEnv :: ByteString -> IO AppEnv
newAppEnv connStr = do
  pool <- newPool $ setNumStripes (Just 1) $ defaultPoolConfig (connectPostgreSQL connStr) close 30 10
  ls <- newStdoutLoggerSet defaultBufSize
  redisUrl <- requireEnv "BACKEND_REDIS_URL"
  connInfo <- case R.parseConnectInfo redisUrl of
    Left err -> fail ("invalid BACKEND_REDIS_URL: " <> err)
    Right ci -> pure ci
  redis <- R.checkedConnect connInfo
  pure AppEnv {appPool = pool, appLoggerSet = ls, appRedis = redis}
