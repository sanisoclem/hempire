module Main (main) where

import Ledger.Handlers (postEntryH)
import Ledger.Types
import Data.IORef (newIORef)
import Effectful hiding (type (:>))
import Effectful.Error.Static (Error, runError)
import Network.Wai.Handler.Warp qualified as Warp
import Servant

import Hempire.AppEnv (AppEnv (..), newAppEnv)
import Hempire.Effect.Auth (Auth)
import Hempire.Effect.Database (Database, DatabaseError)
import Hempire.Effect.Events (Events)
import Hempire.Effect.Logging (Logging)
import Hempire.Effect.Time (Time)
import Hempire.Interpreter.Auth.IORef (runAuthIORef)
import Hempire.Interpreter.Database.Postgres (runDatabasePostgres)
import Hempire.Interpreter.Events.Outbox (runEventsOutbox)
import Hempire.Interpreter.Logging.FastLogger (runLoggingFastLogger)
import Hempire.Interpreter.Time.System (runTimeSystem)

import Ledger.Core.Repository (LedgerRepository)
import Ledger.Interpreter.Repository.Postgres (runLedgerRepositoryPostgres)

type API
  = "entries" :> ReqBody '[JSON] PostEntry :> Post '[JSON] (LedgerResponse EntryId)

-- | Full effect stack for this service.
type App a = Eff '[Error ServerError, LedgerRepository, Events, Database, Time, Auth, Logging, IOE] a

appToHandler :: AppEnv -> App a -> Handler a
appToHandler env action = do
  principalRef <- liftIO $ newIORef Nothing
  outcome      <- liftIO $ runEff
    $ runLoggingFastLogger (appLoggerSet env)
    $ runAuthIORef principalRef
    $ runTimeSystem
    $ runDatabasePostgres (appPool env)
    $ runEventsOutbox
    $ runLedgerRepositoryPostgres
    $ runError @ServerError action
  case outcome of
    Left  dbErr             -> liftIO (logDbError dbErr) >> throwError err500
    Right (Left  (_, sErr)) -> throwError sErr
    Right (Right a)         -> pure a
  where
    logDbError :: DatabaseError -> IO ()
    logDbError err = putStrLn ("[ledger-api] database error: " <> show err)

server :: AppEnv -> Server API
server env =
  hoistServer (Proxy @API) (appToHandler env) postEntryH

main :: IO ()
main = do
  env <- newAppEnv
  putStrLn "ledger-api listening on :8081"
  Warp.run 8081 (serve (Proxy @API) (server env))
