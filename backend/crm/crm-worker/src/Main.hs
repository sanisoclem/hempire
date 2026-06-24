module Main (main) where

import Crm.Core.CustomerContext (CustomerContext)
import Crm.Core.Idp (Idp)
import Crm.Core.Repository (CrmRepository)
import Crm.Interpreter.CustomerContext (runInternalContext)
import Crm.Interpreter.Idp.Zitadel (ZitadelConfig (..), runIdpZitadel)
import Crm.Interpreter.Repository.Postgres (runCrmRepositoryPostgres)
import Crm.Types (CrmCommand)
import Crm.Worker.Handler (handleCommand)
import Data.Aeson (eitherDecodeStrict)
import Data.ByteString (ByteString)
import Data.Text qualified as T
import Effectful
import Hempire.AppEnv (AppEnv (..), newAppEnv)
import Hempire.Effect.Database (Database, DatabaseError)
import Hempire.Effect.Events (Events)
import Hempire.Effect.IdGen (IdGen)
import Hempire.Effect.Logging (Logging)
import Hempire.Effect.Time (Time)
import Hempire.Interpreter.Database.Postgres (runDatabasePostgres)
import Hempire.Interpreter.Events.Outbox (runEventsOutbox)
import Hempire.Interpreter.IdGen.Real (runIdGenReal)
import Hempire.Interpreter.Logging.FastLogger (runLoggingFastLogger)
import Hempire.Interpreter.Time.System (runTimeSystem)
import Kafka.Consumer qualified as KC
import System.Environment (lookupEnv)

type App a = Eff
  '[ CustomerContext
   , Idp
   , CrmRepository
   , IdGen
   , Events
   , Database
   , Time
   , Logging
   , IOE
   ] a

runApp :: AppEnv -> ZitadelConfig -> App () -> IO (Either DatabaseError ())
runApp env zCfg action = runEff
  $ runLoggingFastLogger (appLoggerSet env)
  $ runTimeSystem
  $ runDatabasePostgres (appPool env)
  $ runEventsOutbox
  $ runIdGenReal
  $ runCrmRepositoryPostgres
  $ runIdpZitadel zCfg
  $ runInternalContext action

consumerProps :: String -> KC.ConsumerProperties
consumerProps brokers =
  KC.brokersList [KC.BrokerAddress (T.pack brokers)]
    <> KC.groupId (KC.ConsumerGroupId "crm-worker")
    <> KC.noAutoCommit

subscription :: KC.Subscription
subscription = KC.topics ["crm.commands"]

main :: IO ()
main = do
  env     <- newAppEnv
  zCfg    <- loadZitadelConfig
  brokers <- maybe "localhost:9092" id <$> lookupEnv "KAFKA_BROKERS"
  KC.newConsumer (consumerProps brokers) subscription >>= \case
    Left err       -> error ("crm-worker: failed to create consumer: " <> show err)
    Right consumer -> do
      putStrLn "crm-worker started"
      loop env zCfg consumer

loop :: AppEnv -> ZitadelConfig -> KC.KafkaConsumer -> IO ()
loop env zCfg consumer = do
  KC.pollMessage consumer (KC.Timeout 1000) >>= \case
    Left (KC.KafkaResponseError KC.RdKafkaRespErrTimedOut) ->
      loop env zCfg consumer
    Left err ->
      putStrLn ("crm-worker: poll error: " <> show err) >> loop env zCfg consumer
    Right msg -> do
      dispatch env zCfg msg
      _ <- KC.commitAllOffsets KC.OffsetCommit consumer
      loop env zCfg consumer

dispatch
  :: AppEnv
  -> ZitadelConfig
  -> KC.ConsumerRecord (Maybe ByteString) (Maybe ByteString)
  -> IO ()
dispatch env zCfg msg = case KC.crValue msg of
  Nothing    -> pure ()
  Just bytes -> case eitherDecodeStrict @CrmCommand bytes of
    Left err  -> putStrLn ("crm-worker: decode error: " <> err)
    Right cmd ->
      runApp env zCfg (handleCommand cmd) >>= \case
        Left dbErr -> putStrLn ("crm-worker: database error: " <> show dbErr)
        Right ()   -> pure ()

loadZitadelConfig :: IO ZitadelConfig
loadZitadelConfig = do
  apiUrl  <- getEnv "ZITADEL_API_URL"       "http://localhost:8081"
  cidStr  <- getEnv "ZITADEL_CLIENT_ID"     ""
  csecret <- getEnv "ZITADEL_CLIENT_SECRET" ""
  pure ZitadelConfig
    { zCfgApiUrl       = T.pack apiUrl
    , zCfgClientId     = T.pack cidStr
    , zCfgClientSecret = T.pack csecret
    }
  where
    getEnv k d = maybe d id <$> lookupEnv k
