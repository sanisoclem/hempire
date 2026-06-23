module Main (main) where

import Crm.Handlers (createContactH, updateContactH)
import Crm.Types
import Data.IORef (newIORef)
import Data.Text (Text)
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

import Crm.Core.Repository (CrmRepository)
import Crm.Interpreter.Repository.Postgres (runCrmRepositoryPostgres)

type API
  =    "contacts" :> ReqBody '[JSON] CreateContact :> Post '[JSON] (CrmResponse ContactId)
  :<|> "contacts" :> Capture "id" Text :> ReqBody '[JSON] UpdateContact :> Put '[JSON] (CrmResponse ContactId)

type App a = Eff '[Error ServerError, CrmRepository, Events, Database, Time, Auth, Logging, IOE] a

appToHandler :: AppEnv -> App a -> Handler a
appToHandler env action = do
  principalRef <- liftIO $ newIORef Nothing
  outcome      <- liftIO $ runEff
    $ runLoggingFastLogger (appLoggerSet env)
    $ runAuthIORef principalRef
    $ runTimeSystem
    $ runDatabasePostgres (appPool env)
    $ runEventsOutbox
    $ runCrmRepositoryPostgres
    $ runError @ServerError action
  case outcome of
    Left  dbErr              -> liftIO (logDbError dbErr) >> throwError err500
    Right (Left  (_, sErr))  -> throwError sErr
    Right (Right a)          -> pure a
  where
    logDbError :: DatabaseError -> IO ()
    logDbError err = putStrLn ("[crm-api] database error: " <> show err)

server :: AppEnv -> Server API
server env =
  hoistServer (Proxy @API) (appToHandler env)
    (createContactH :<|> updateContactH)

main :: IO ()
main = do
  env <- newAppEnv
  putStrLn "crm-api listening on :8080"
  Warp.run 8080 (serve (Proxy @API) (server env))
