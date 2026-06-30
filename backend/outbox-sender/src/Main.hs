module Main where

import Control.Concurrent (threadDelay)
import Control.Concurrent.Async (forConcurrently_)
import Control.Exception (throwIO)
import Control.Monad (forM_, forever)
import Data.ByteString (ByteString)
import Data.Int (Int64)
import Data.Pool (Pool, defaultPoolConfig, newPool, setNumStripes)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding (encodeUtf8)
import Database.PostgreSQL.Simple (Connection, FromRow, Only (..), close, connectPostgreSQL)
import Database.PostgreSQL.Simple.FromRow (field, fromRow)
import Effectful
import Hempire.Effect.Database (Database, runQuery, runQuery_)
import Hempire.Effect.Messaging (Messaging, sendMessage)
import Hempire.Interpreter.Database.Postgres (runDatabasePostgres)
import Hempire.Interpreter.Messaging.Kafka (runMessagingKafka)
import Kafka.Producer
import System.Environment (getEnv)
import System.IO (hPutStrLn, stderr)

data OutboxMessage = OutboxMessage
  { msgId :: Int64
  , msgTopic :: Text
  , msgPayload :: Text
  }

instance FromRow OutboxMessage where
  fromRow = OutboxMessage <$> field <*> field <*> field

mkPool :: ByteString -> IO (Pool Connection)
mkPool connStr =
  newPool $
    setNumStripes (Just 1) $
      defaultPoolConfig (connectPostgreSQL connStr) close 30 5

main :: IO ()
main = do
  urlsStr <- getEnv "BACKEND_OUTBOX_DATABASE_URLS"
  brokersStr <- getEnv "BACKEND_KAFKA_BROKERS"
  let connStrs = map (encodeUtf8 . T.strip) $ T.splitOn "," (T.pack urlsStr)
      brokers = map (BrokerAddress . T.strip) $ T.splitOn "," (T.pack brokersStr)
  producer <-
    newProducer (brokersList brokers <> sendTimeout (Timeout 10000))
      >>= either (throwIO . userError . show) pure
  pools <- mapM mkPool connStrs
  forConcurrently_ pools $ \pool ->
    forever $ do
      result <-
        runEff $
          runDatabasePostgres pool $
            runMessagingKafka
              producer
              processOutbox
      case result of
        Left err -> hPutStrLn stderr ("outbox error: " <> show err)
        Right () -> pure ()
      threadDelay 1_000_000

processOutbox :: (Database :> es, Messaging :> es) => Eff es ()
processOutbox = do
  msgs :: [OutboxMessage] <- runQuery "SELECT id, topic, payload::text FROM outbox ORDER BY id LIMIT 100" ()
  forM_ msgs $ \msg -> do
    sendMessage msg.msgTopic (encodeUtf8 msg.msgPayload)
    runQuery_ "DELETE FROM outbox WHERE id = ?" (Only msg.msgId)
