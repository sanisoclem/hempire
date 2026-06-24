module Main (main) where

import Ledger.Types (LedgerCommand)
import Ledger.Worker.Handler (handleCommand)
import Data.Aeson (eitherDecodeStrict)
import Data.ByteString (ByteString)
import Data.Text qualified as T
import Effectful
import Kafka.Consumer qualified as KC
import System.Environment (lookupEnv)

import Ledger.Core.Repository (LedgerRepository)
import Ledger.Interpreter.Repository.Postgres (runLedgerRepositoryPostgres)
import Hempire.AppEnv (AppEnv (..), newAppEnv)
import Hempire.Effect.Database (Database, DatabaseError)
import Hempire.Effect.Events (Events)
import Hempire.Effect.Logging (Logging)
import Hempire.Effect.Time (Time)
import Hempire.Interpreter.Database.Postgres (runDatabasePostgres)
import Hempire.Interpreter.Events.Outbox (runEventsOutbox)
import Hempire.Interpreter.Logging.FastLogger (runLoggingFastLogger)
import Hempire.Interpreter.Time.System (runTimeSystem)

-- | Full effect stack for command handling.
-- Events are written to the outbox table and relayed to Kafka separately.
type App a = Eff '[LedgerRepository, Events, Database, Time, Logging, IOE] a

runApp :: AppEnv -> App () -> IO (Either DatabaseError ())
runApp env action = runEff
  $ runLoggingFastLogger (appLoggerSet env)
  $ runTimeSystem
  $ runDatabasePostgres (appPool env)
  $ runEventsOutbox
  $ runLedgerRepositoryPostgres action

consumerProps :: String -> KC.ConsumerProperties
consumerProps brokers =
  KC.brokersList [KC.BrokerAddress (T.pack brokers)]
    <> KC.groupId (KC.ConsumerGroupId "ledger-worker")
    <> KC.noAutoCommit

-- | All Ledger commands arrive on a single topic.
-- Cross-domain event reactions are added here as additional topics.
subscription :: KC.Subscription
subscription = KC.topics ["ledger.commands"]

main :: IO ()
main = do
  env     <- newAppEnv
  brokers <- maybe "localhost:9092" id <$> lookupEnv "KAFKA_BROKERS"
  KC.newConsumer (consumerProps brokers) subscription >>= \case
    Left err       -> error ("ledger-worker: failed to create consumer: " <> show err)
    Right consumer -> do
      putStrLn "ledger-worker started"
      loop env consumer

loop :: AppEnv -> KC.KafkaConsumer -> IO ()
loop env consumer = do
  KC.pollMessage consumer (KC.Timeout 1000) >>= \case
    Left (KC.KafkaResponseError KC.RdKafkaRespErrTimedOut) ->
      loop env consumer
    Left err ->
      putStrLn ("ledger-worker: poll error: " <> show err) >> loop env consumer
    Right msg -> do
      dispatch env msg
      _ <- KC.commitAllOffsets KC.OffsetCommit consumer
      loop env consumer

dispatch
  :: AppEnv
  -> KC.ConsumerRecord (Maybe ByteString) (Maybe ByteString)
  -> IO ()
dispatch env msg = case KC.crValue msg of
  Nothing    -> pure ()
  Just bytes -> case eitherDecodeStrict @LedgerCommand bytes of
    Left err  -> putStrLn ("ledger-worker: decode error: " <> err)
    Right cmd ->
      runApp env (handleCommand cmd) >>= \case
        Left dbErr -> putStrLn ("ledger-worker: database error: " <> show dbErr)
        Right ()   -> pure ()
