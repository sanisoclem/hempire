module Main (main) where

import Control.Concurrent (forkIO, threadDelay)
import Control.Exception (SomeException, try)
import Control.Monad (forever)
import Crm.AppEnv (newCrmAppEnv)
import Crm.Auth
import Crm.Core (CrmRepository, Idp)
import Crm.Core.Domain (CrmDomainError)
import Crm.Handlers
import Crm.Interpreter.Error (mapCrmError)
import Crm.Interpreter.Idp.Zitadel (ZitadelConfig (..), runIdpZitadel)
import Crm.Interpreter.Repository.Postgres (runCrmRepositoryPostgres)
import Crm.Types
import Crypto.JOSE.JWK (JWKSet)
import Data.Aeson (encode)
import Data.Default (def)
import Data.IORef (IORef, newIORef, writeIORef)
import Data.Text qualified as T
import Data.UUID qualified as UUID
import Data.UUID.V4 (nextRandom)
import Effectful hiding ((:>))
import Effectful.Error.Static (Error, runError)
import Hempire.AppEnv (AppEnv (..))
import Hempire.Effect.CustomerContext (CustomerContext)
import Hempire.Effect.Database (Database, DatabaseError, withTransaction)
import Hempire.Effect.Events (Events)
import Hempire.Effect.IdGen (IdGen)
import Hempire.Effect.Logging (Logging)
import Hempire.Effect.Time (Time)
import Hempire.Interpreter.Auth.Jwt (fetchJwks)
import Hempire.Interpreter.CustomerContext (runCustomerContext, runInternalContext)
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
import System.Environment (lookupEnv, setEnv)

type CrmAuth = AuthProtect "crm-customer"

type API =
  "onboarding"
    :> CrmAuth
    :> ReqBody '[JSON] OnboardRequest
    :> Post '[JSON] OnboardResponse

type App a =
  Eff
    '[ Error ServerError
     , Error CrmDomainError
     , CustomerContext
     , Idp
     , CrmRepository
     , IdGen
     , Events
     , Database
     , Time
     , Logging
     , IOE
     ]
    a

appToHandler :: AppEnv -> ZitadelConfig -> CustomerAuth -> App (CrmResponse a) -> Handler a
appToHandler env zCfg auth action = do
  outcome <-
    liftIO $
      runEff $
        runLoggingFastLogger (appLoggerSet env) $
          runTimeSystem $
            runDatabasePostgres (appPool env) $
              runEventsOutbox $
                runIdGenReal $
                  runCrmRepositoryPostgres $
                    runIdpZitadel zCfg $
                      runContextFor (cauthCustomerId auth) $
                        withTransaction $
                          runError @CrmDomainError $
                            runError @ServerError action
  case outcome of
    Left dbErr -> liftIO (logDbError dbErr) >> throwError err500
    Right (Left (_, domainErr)) -> case mapCrmError domainErr of
      Just e -> throwError (toHttpError e)
      Nothing -> throwError err500
    Right (Right (Left (_, sErr))) -> throwError sErr
    Right (Right (Right (Ok a))) -> pure a
    Right (Right (Right (Err e))) -> throwError (toHttpError e)
 where
  logDbError :: DatabaseError -> IO ()
  logDbError err = putStrLn ("[crm-api] database error: " <> show err)

runContextFor :: Maybe CustomerId -> Eff (CustomerContext : es) a -> Eff es a
runContextFor (Just cid) = runCustomerContext cid
runContextFor Nothing = runInternalContext

server :: AppEnv -> ZitadelConfig -> Server API
server env zCfg =
  \auth req -> run auth (onboardCustomerH auth req)
 where
  run :: forall a. CustomerAuth -> App (CrmResponse a) -> Handler a
  run = appToHandler env zCfg

main :: IO ()
main = do
  setEnv "OTEL_SERVICE_NAME" "crm-api"
  withOpenTelemetry $ \_ -> do
    env <- newCrmAppEnv
    jwtCfg <- loadCustomerJwtConfig
    zCfg <- loadZitadelConfig
    keys <- fetchJwks (cfgJwksUri jwtCfg) >>= newIORef
    _ <- forkIO (jwksRefreshLoop (cfgJwksUri jwtCfg) keys)
    _ <- forkIO $ Warp.run 10001 metricsApp
    otelMW <- newOpenTelemetryWaiMiddleware
    port <- read <$> requireEnv "CRM_API_PORT"
    let authHandler = makeCustomerAuthHandler jwtCfg keys
        ctx = authHandler :. EmptyContext
        app = otelMW $ requestIdMiddleware $ prometheus def $ serveWithContext (Proxy @API) ctx (server env zCfg)
    putStrLn $ "crm-api listening on :" <> show port
    Warp.run port app

toHttpError :: CrmError -> ServerError
toHttpError e = base {errBody = encode e, errHeaders = [("content-type", "application/json")]}
 where
  base = case e of
    NotFound _ -> err404
    ValidationFailed _ -> err400
    Conflict _ -> err400
    InviteAlreadyClaimed _ -> err400

requestIdMiddleware :: Application -> Application
requestIdMiddleware inner req k = do
  rid <- UUID.toText <$> nextRandom
  ctx <- getContext
  mapM_ (\sp -> addAttribute sp "request_id" rid) (lookupSpan ctx)
  withRequestId rid $ inner req k

jwksRefreshLoop :: String -> IORef JWKSet -> IO ()
jwksRefreshLoop uri ref = forever $ do
  threadDelay (5 * 60 * 1_000_000)
  result <- try @SomeException (fetchJwks uri)
  case result of
    Left _ -> pure ()
    Right keys -> writeIORef ref keys

loadZitadelConfig :: IO ZitadelConfig
loadZitadelConfig = do
  apiUrl <- requireEnv "CRM_ZITADEL_API_URL"
  cidStr <- requireEnv "CRM_ZITADEL_CLIENT_ID"
  csecret <- requireEnv "CRM_ZITADEL_CLIENT_SECRET"
  pure
    ZitadelConfig
      { zCfgApiUrl = T.pack apiUrl
      , zCfgClientId = T.pack cidStr
      , zCfgClientSecret = T.pack csecret
      }

requireEnv :: String -> IO String
requireEnv k = lookupEnv k >>= maybe (fail ("required env var not set: " <> k)) pure
