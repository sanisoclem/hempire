module Main (main) where

import Crm.Auth
import Crm.Core (CrmRepository, CustomerContext, Idp)
import Crm.Handlers
import Crm.Interpreter.CustomerContext (runCustomerContext, runInternalContext)
import Crm.Interpreter.Idp.Zitadel (ZitadelConfig (..), runIdpZitadel)
import Crm.Interpreter.Repository.Postgres (runCrmRepositoryPostgres)
import Crm.Types
import Data.IORef (newIORef)
import Data.Text qualified as T
import Effectful hiding ((:>))
import Effectful.Error.Static (Error, runError)
import Hempire.AppEnv (AppEnv (..), newAppEnv)
import Hempire.Effect.Database (Database, DatabaseError)
import Hempire.Effect.Events (Events)
import Hempire.Effect.IdGen (IdGen)
import Hempire.Effect.Logging (Logging)
import Hempire.Effect.Time (Time)
import Hempire.Interpreter.Auth.Jwt (fetchJwks)
import Hempire.Interpreter.Database.Postgres (runDatabasePostgres)
import Hempire.Interpreter.Events.Outbox (runEventsOutbox)
import Hempire.Interpreter.IdGen.Real (runIdGenReal)
import Hempire.Interpreter.Logging.FastLogger (runLoggingFastLogger)
import Hempire.Interpreter.Time.System (runTimeSystem)
import Network.Wai.Handler.Warp qualified as Warp
import Servant
import System.Environment (lookupEnv)

type CrmAuth = AuthProtect "crm-jwt"

type API
  =    "onboarding" :> CrmAuth :> ReqBody '[JSON] OnboardCustomer
         :> Post '[JSON] (CrmResponse CustomerId)
  :<|> "invites"    :> CrmAuth :> ReqBody '[JSON] CreateInvite
         :> Post '[JSON] (CrmResponse InviteId)
  :<|> "invites"    :> Capture "id" InviteId :> CrmAuth
         :> Get '[JSON] (CrmResponse InviteDetails)
  :<|> "invites"    :> Capture "id" InviteId :> CrmAuth
         :> Delete '[JSON] (CrmResponse ())
  :<|> "customers"  :> Capture "id" CustomerId :> "deactivate" :> CrmAuth
         :> Post '[JSON] (CrmResponse ())

type App a = Eff
  '[ Error ServerError
   , CustomerContext
   , Idp
   , CrmRepository
   , IdGen
   , Events
   , Database
   , Time
   , Logging
   , IOE
   ] a

appToHandler :: AppEnv -> ZitadelConfig -> CrmAuthResult -> App a -> Handler a
appToHandler env zCfg auth action = do
  outcome <- liftIO $ runEff
    $ runLoggingFastLogger (appLoggerSet env)
    $ runTimeSystem
    $ runDatabasePostgres (appPool env)
    $ runEventsOutbox
    $ runIdGenReal
    $ runCrmRepositoryPostgres
    $ runIdpZitadel zCfg
    $ runCustomerContext' auth
    $ runError @ServerError action
  case outcome of
    Left dbErr             -> liftIO (logDbError dbErr) >> throwError err500
    Right (Left (_, sErr)) -> throwError sErr
    Right (Right a)        -> pure a
  where
    logDbError :: DatabaseError -> IO ()
    logDbError err = putStrLn ("[crm-api] database error: " <> show err)

runCustomerContext' :: CrmAuthResult -> Eff (CustomerContext : es) a -> Eff es a
runCustomerContext' (BffAuth _ (Just cid)) = runCustomerContext cid
runCustomerContext' _                      = runInternalContext

server :: AppEnv -> ZitadelConfig -> Server API
server env zCfg =
    (\auth cmd -> run auth (onboardCustomerH auth cmd))
  :<|> (\auth cmd -> run auth (createInviteH auth cmd))
  :<|> (\iid auth -> run auth (getInviteH iid auth))
  :<|> (\iid auth -> run auth (deleteInviteH iid auth))
  :<|> (\cid auth -> run auth (deactivateCustomerH cid auth))
  where
    run :: forall a. CrmAuthResult -> App a -> Handler a
    run = appToHandler env zCfg

main :: IO ()
main = do
  env     <- newAppEnv
  jwtCfg  <- loadCrmJwtConfig
  zCfg    <- loadZitadelConfig
  bffKeys <- fetchJwks (cfgBffJwksUri jwtCfg) >>= newIORef
  intKeys <- fetchJwks (cfgIntJwksUri jwtCfg)  >>= newIORef
  let authHandler = makeCrmAuthHandler jwtCfg bffKeys intKeys
      ctx         = authHandler :. EmptyContext
      app         = serveWithContext (Proxy @API) ctx (server env zCfg)
  putStrLn "crm-api listening on :8080"
  Warp.run 8080 app

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
