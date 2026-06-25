module Hempire.AppEnv (
  AppEnv (..),
  newAppEnv,
) where

import Data.ByteString (ByteString)
import Data.Pool (Pool, defaultPoolConfig, newPool)
import Database.PostgreSQL.Simple (Connection, close, connectPostgreSQL)
import System.Log.FastLogger (LoggerSet, defaultBufSize, newStdoutLoggerSet)

data AppEnv = AppEnv
  { appPool :: Pool Connection
  , appLoggerSet :: LoggerSet
  }

newAppEnv :: ByteString -> IO AppEnv
newAppEnv connStr = do
  pool <- newPool $ defaultPoolConfig (connectPostgreSQL connStr) close 30 10
  ls <- newStdoutLoggerSet defaultBufSize
  pure AppEnv {appPool = pool, appLoggerSet = ls}
