module Hempire.AppEnv
  ( AppEnv (..)
  , newAppEnv
  ) where

import Data.ByteString (ByteString)
import Data.ByteString.Char8 qualified as BS8
import Data.Pool (Pool, createPool)
import Database.PostgreSQL.Simple (Connection, close, connectPostgreSQL)
import System.Environment (lookupEnv)
import System.Log.FastLogger (LoggerSet, defaultBufSize, newStdoutLoggerSet)

data AppEnv = AppEnv
  { appPool      :: Pool Connection
  , appLoggerSet :: LoggerSet
  }

newAppEnv :: IO AppEnv
newAppEnv = do
  dbUrl <- maybe defaultDb BS8.pack <$> lookupEnv "DATABASE_URL"
  pool  <- createConnectionPool dbUrl
  ls    <- newStdoutLoggerSet defaultBufSize
  pure AppEnv { appPool = pool, appLoggerSet = ls }
  where
    defaultDb = "postgres://hempire:hempire@localhost:5432/hempire_bff"

createConnectionPool :: ByteString -> IO (Pool Connection)
createConnectionPool connStr =
  createPool (connectPostgreSQL connStr) close
    1    -- stripes
    30   -- keep-alive seconds
    10   -- max connections per stripe
