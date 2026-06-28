module Main (main) where

import Crm.AppEnv (newCrmAppEnv)
import Crm.Auth
import Crm.Core (CrmRepository, Idp)
import Crm.Core.Domain (CrmDomainError)
import Crm.Handlers
import Crm.Interpreter.Error (mapCrmError)
import Crm.Interpreter.Idp.Zitadel (ZitadelConfig (..), runIdpZitadel)
import Crm.Interpreter.Repository.Postgres (runCrmRepositoryPostgres)
import Crm.Types
import Data.IORef (newIORef)
import Data.Text qualified as T
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
import Hempire.Interpreter.CustomerContext (runCustomerContext, runInternalContext)
import Hempire.Interpreter.Database.Postgres (runDatabasePostgres)
import Hempire.Interpreter.Events.Outbox (runEventsOutbox)
import Hempire.Interpreter.IdGen.Real (runIdGenReal)
import Hempire.Interpreter.Logging.FastLogger (runLoggingFastLogger)
import Hempire.Interpreter.Time.System (runTimeSystem)
import Network.Wai.Handler.Warp qualified as Warp
import Servant
import System.Environment (lookupEnv)

type CrmAuth = AuthProtect "crm-customer"

type API =
  "onboarding"
    :> CrmAuth
    :> ReqBody '[JSON] OnboardRequest
    :> Post '[JSON] (CrmResponse CustomerId)

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

appToHandler :: AppEnv -> ZitadelConfig -> CustomerAuth -> App (CrmResponse a) -> Handler (CrmResponse a)
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
  logDbError err = putStrLn ("[crm-api] database error: " <> show err)

runContextFor :: Maybe CustomerId -> Eff (CustomerContext : es) a -> Eff es a
runContextFor (Just cid) = runCustomerContext cid
runContextFor Nothing = runInternalContext

server :: AppEnv -> ZitadelConfig -> Server API
server env zCfg =
  \auth req -> run auth (onboardCustomerH auth req)
 where
  run :: forall a. CustomerAuth -> App (CrmResponse a) -> Handler (CrmResponse a)
  run = appToHandler env zCfg

main :: IO ()
main = do
  env <- newCrmAppEnv
  jwtCfg <- loadCustomerJwtConfig
  zCfg <- loadZitadelConfig
  keys <- fetchJwks (cfgJwksUri jwtCfg) >>= newIORef
  let authHandler = makeCustomerAuthHandler jwtCfg keys
      ctx = authHandler :. EmptyContext
      app = serveWithContext (Proxy @API) ctx (server env zCfg)
  port <- read <$> requireEnv "CRM_API_PORT"
  putStrLn $ "crm-api listening on :" <> show port
  Warp.run port app

loadZitadelConfig :: IO ZitadelConfig
loadZitadelConfig = do
  apiUrl <- requireEnv "ZITADEL_API_URL"
  cidStr <- requireEnv "ZITADEL_CLIENT_ID"
  csecret <- requireEnv "ZITADEL_CLIENT_SECRET"
  pure
    ZitadelConfig
      { zCfgApiUrl = T.pack apiUrl
      , zCfgClientId = T.pack cidStr
      , zCfgClientSecret = T.pack csecret
      }

requireEnv :: String -> IO String
requireEnv k = lookupEnv k >>= maybe (fail ("required env var not set: " <> k)) pure
