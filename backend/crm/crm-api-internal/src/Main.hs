module Main (main) where

import Control.Concurrent (forkIO)
import Crm.AppEnv (newCrmAppEnv)
import Crm.Auth
import Crm.Core (CrmRepository)
import Crm.Core.Domain (CrmDomainError)
import Crm.Handlers
import Crm.Interpreter.Error (mapCrmError)
import Crm.Interpreter.Repository.Postgres (runCrmRepositoryPostgres)
import Crm.Types
import Data.Default (def)
import Data.IORef (newIORef)
import Data.UUID qualified as UUID
import Data.UUID.V4 (nextRandom)
import Effectful hiding ((:>))
import Effectful.Error.Static (Error, runError)
import Hempire.AppEnv (AppEnv (..))
import Hempire.Effect.CustomerContext (CustomerContext)
import Hempire.Effect.Database (Database, DatabaseError)
import Hempire.Effect.Events (Events)
import Hempire.Effect.IdGen (IdGen)
import Hempire.Effect.Logging (Logging)
import Hempire.Effect.Time (Time)
import Hempire.Interpreter.Auth.Jwt (fetchJwks)
import Hempire.Interpreter.CustomerContext (runInternalContext)
import Hempire.Interpreter.Database.Postgres (runDatabasePostgres)
import Hempire.Interpreter.Events.Outbox (runEventsOutbox)
import Hempire.Interpreter.IdGen.Real (runIdGenReal)
import Hempire.Interpreter.Logging.FastLogger (runLoggingFastLogger)
import Hempire.Interpreter.Telemetry (withRequestId)
import Hempire.Interpreter.Time.System (runTimeSystem)
import Network.Wai.Handler.Warp qualified as Warp
import Network.Wai.Middleware.Prometheus (metricsApp, prometheus)
import OpenTelemetry.Context (lookupSpan)
import OpenTelemetry.Context.ThreadLocal (getContext)
import OpenTelemetry.Instrumentation.Wai (newOpenTelemetryWaiMiddleware)
import OpenTelemetry.SDK (withOpenTelemetry)
import OpenTelemetry.Trace.Core (addAttribute)
import Servant
import System.Environment (setEnv)

type InternalAuth' = AuthProtect "crm-internal"

type API =
    "invites"
        :> InternalAuth'
        :> ReqBody '[JSON] CreateInvite
        :> Post '[JSON] (CrmResponse InviteId)
        :<|> "invites"
            :> InternalAuth'
            :> Capture "id" InviteId
            :> Get '[JSON] (CrmResponse InviteDetails)
        :<|> "invites"
            :> InternalAuth'
            :> Capture "id" InviteId
            :> Delete '[JSON] (CrmResponse ())
        :<|> "customers"
            :> InternalAuth'
            :> Capture "id" CustomerId
            :> "deactivate"
            :> Post '[JSON] (CrmResponse ())

type App a =
    Eff
        '[ Error ServerError
         , Error CrmDomainError
         , CustomerContext
         , CrmRepository
         , IdGen
         , Events
         , Database
         , Time
         , Logging
         , IOE
         ]
        a

appToHandler :: AppEnv -> InternalAuth -> App (CrmResponse a) -> Handler (CrmResponse a)
appToHandler env _auth action = do
    outcome <-
        liftIO $
            runEff $
                runLoggingFastLogger (appLoggerSet env) $
                    runTimeSystem $
                        runDatabasePostgres (appPool env) $
                            runEventsOutbox $
                                runIdGenReal $
                                    runCrmRepositoryPostgres $
                                        runInternalContext $
                                            runError @CrmDomainError $
                                                runError @ServerError action
    case outcome of
        Left dbErr -> liftIO (logDbError dbErr) >> throwError err500
        Right (Left (_, domainErr)) -> case mapCrmError domainErr of
            Just e -> pure (Err e)
            Nothing -> throwError err500
        Right (Right (Left (_, sErr))) -> throwError sErr
        Right (Right (Right a)) -> pure a
  where
    logDbError :: DatabaseError -> IO ()
    logDbError err = putStrLn ("[crm-api-internal] database error: " <> show err)

requestIdMiddleware :: Application -> Application
requestIdMiddleware inner req k = do
    rid <- UUID.toText <$> nextRandom
    ctx <- getContext
    mapM_ (\sp -> addAttribute sp "request_id" rid) (lookupSpan ctx)
    withRequestId rid $ inner req k

server :: AppEnv -> Server API
server env =
    (\auth req -> run auth (createInviteH auth req))
        :<|> (\auth iid -> run auth (getInviteH auth iid))
        :<|> (\auth iid -> run auth (deleteInviteH auth iid))
        :<|> (\auth cid -> run auth (deactivateCustomerH auth cid))
  where
    run :: forall a. InternalAuth -> App (CrmResponse a) -> Handler (CrmResponse a)
    run = appToHandler env

main :: IO ()
main = do
    setEnv "OTEL_SERVICE_NAME" "crm-api-internal"
    withOpenTelemetry $ \_ -> do
        env <- newCrmAppEnv
        jwtCfg <- loadInternalJwtConfig
        keys <- fetchJwks (cfgJwksUri jwtCfg) >>= newIORef
        _ <- forkIO $ Warp.run 10002 metricsApp
        otelMW <- newOpenTelemetryWaiMiddleware
        let authHandler = makeInternalAuthHandler jwtCfg keys
            ctx = authHandler :. EmptyContext
            app = otelMW $ requestIdMiddleware $ prometheus def $ serveWithContext (Proxy @API) ctx (server env)
        putStrLn "crm-api-internal listening on :8090"
        Warp.run 8090 app
