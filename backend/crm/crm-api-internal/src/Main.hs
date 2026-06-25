module Main (main) where

import Crm.Auth
import Crm.Core (CrmRepository)
import Crm.Core.Domain (CrmDomainError)
import Crm.Handlers
import Crm.Interpreter.Repository.Postgres (runCrmRepositoryPostgres)
import Crm.Types
import Data.IORef (newIORef)
import Effectful hiding ((:>))
import Effectful.Error.Static (Error, runError)
import Hempire.AppEnv (AppEnv (..), newAppEnv)
import Hempire.Effect.CustomerContext (CustomerContext)
import Hempire.Effect.Database (Database, DatabaseError)
import Hempire.Effect.Events (Events)
import Hempire.Effect.IdGen (IdGen)
import Hempire.Effect.Logging (Logging)
import Hempire.Effect.Time (Time)
import Hempire.Id (CustomerId)
import Hempire.Interpreter.Auth.Jwt (fetchJwks)
import Hempire.Interpreter.CustomerContext (runInternalContext)
import Hempire.Interpreter.Database.Postgres (runDatabasePostgres)
import Hempire.Interpreter.Events.Outbox (runEventsOutbox)
import Hempire.Interpreter.IdGen.Real (runIdGenReal)
import Hempire.Interpreter.Logging.FastLogger (runLoggingFastLogger)
import Hempire.Interpreter.Time.System (runTimeSystem)
import Network.Wai.Handler.Warp qualified as Warp
import Servant

type InternalAuth' = AuthProtect "crm-internal"

type API
  =    "invites"   :> InternalAuth' :> ReqBody '[JSON] CreateInvite
         :> Post '[JSON] (CrmResponse InviteId)
  :<|> "invites"   :> InternalAuth' :> Capture "id" InviteId
         :> Get '[JSON] (CrmResponse InviteDetails)
  :<|> "invites"   :> InternalAuth' :> Capture "id" InviteId
         :> Delete '[JSON] (CrmResponse ())
  :<|> "customers" :> InternalAuth' :> Capture "id" CustomerId
         :> "deactivate" :> Post '[JSON] (CrmResponse ())

type App a = Eff
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
   ] a

appToHandler :: AppEnv -> InternalAuth -> App a -> Handler a
appToHandler env _auth action = do
  outcome <- liftIO $ runEff
    $ runLoggingFastLogger (appLoggerSet env)
    $ runTimeSystem
    $ runDatabasePostgres (appPool env)
    $ runEventsOutbox
    $ runIdGenReal
    $ runCrmRepositoryPostgres
    $ runInternalContext
    $ runError @CrmDomainError
    $ runError @ServerError action
  case outcome of
    Left dbErr                     -> liftIO (logDbError dbErr) >> throwError err500
    Right (Left _)                 -> throwError err500  -- unreachable
    Right (Right (Left (_, sErr))) -> throwError sErr
    Right (Right (Right a))        -> pure a
  where
    logDbError :: DatabaseError -> IO ()
    logDbError err = putStrLn ("[crm-api-internal] database error: " <> show err)

server :: AppEnv -> Server API
server env =
       (\auth req -> run auth (createInviteH auth req))
  :<|> (\auth iid -> run auth (getInviteH auth iid))
  :<|> (\auth iid -> run auth (deleteInviteH auth iid))
  :<|> (\auth cid -> run auth (deactivateCustomerH auth cid))
  where
    run :: forall a. InternalAuth -> App a -> Handler a
    run = appToHandler env

main :: IO ()
main = do
  env    <- newAppEnv
  jwtCfg <- loadInternalJwtConfig
  keys   <- fetchJwks (cfgJwksUri jwtCfg) >>= newIORef
  let authHandler = makeInternalAuthHandler jwtCfg keys
      ctx         = authHandler :. EmptyContext
      app         = serveWithContext (Proxy @API) ctx (server env)
  putStrLn "crm-api-internal listening on :8090"
  Warp.run 8090 app
