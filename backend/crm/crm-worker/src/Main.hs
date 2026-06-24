module Main (main) where

import Crm.Types (CrmCommand)
import Crm.Worker.Handler (handleCommand)
import Data.Aeson (eitherDecodeStrict)
import Data.ByteString (ByteString)
import Data.Text qualified as T
import Effectful
import Kafka.Consumer qualified as KC
import System.Environment (lookupEnv)

import Crm.Core.Repository (CrmRepository)
import Crm.Interpreter.Repository.Postgres (runCrmRepositoryPostgres)
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
type App a = Eff '[CrmRepository, Events, Database, Time, Logging, IOE] a

runApp :: AppEnv -> App () -> IO (Either DatabaseError ())
runApp env action = runEff
  $ runLoggingFastLogger (appLoggerSet env)
  $ runTimeSystem
  $ runDatabasePostgres (appPool env)
  $ runEventsOutbox
  $ runCrmRepositoryPostgres action

consumerProps :: String -> KC.ConsumerProperties
consumerProps brokers =
  KC.brokersList [KC.BrokerAddress (T.pack brokers)]
    <> KC.groupId (KC.ConsumerGroupId "crm-worker")
    <> KC.noAutoCommit

-- | All CRM commands arrive on a single topic.
-- Cross-domain event reactions are added here as additional topics.
subscription :: KC.Subscription
subscription = KC.topics ["crm.commands"]

main :: IO ()
main = do
  env     <- newAppEnv
  brokers <- maybe "localhost:9092" id <$> lookupEnv "KAFKA_BROKERS"
  KC.newConsumer (consumerProps brokers) subscription >>= \case
    Left err       -> error ("crm-worker: failed to create consumer: " <> show err)
    Right consumer -> do
      putStrLn "crm-worker started"
      loop env consumer

loop :: AppEnv -> KC.KafkaConsumer -> IO ()
loop env consumer = do
  KC.pollMessage consumer (KC.Timeout 1000) >>= \case
    Left (KC.KafkaResponseError KC.RdKafkaRespErrTimedOut) ->
      loop env consumer
    Left err ->
      putStrLn ("crm-worker: poll error: " <> show err) >> loop env consumer
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
  Just bytes -> case eitherDecodeStrict @CrmCommand bytes of
    Left err  -> putStrLn ("crm-worker: decode error: " <> err)
    Right cmd ->
      runApp env (handleCommand cmd) >>= \case
        Left dbErr -> putStrLn ("crm-worker: database error: " <> show dbErr)
        Right ()   -> pure ()
