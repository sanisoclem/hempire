module Crm.Auth
  ( CrmAuthResult (..)
  , CrmJwtConfig (..)
  , loadCrmJwtConfig
  , makeCrmAuthHandler
  ) where

import Control.Lens ((^.), at)
import Control.Monad.IO.Class (liftIO)
import Crm.Types (CustomerId)
import Crypto.JWT (ClaimsSet, StringOrURI, claimSub, unregisteredClaims)
import Crypto.JOSE.JWK (JWKSet)
import Data.Aeson qualified as A
import Data.ByteString qualified as BS
import Data.IORef (IORef, readIORef)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding (decodeUtf8, encodeUtf8)
import Hempire.DomainId (DomainId (..), parseId)
import Hempire.Interpreter.Auth.Jwt (validateJwt)
import Network.Wai (Request, requestHeaders)
import Servant (Handler, ServerError, err401, throwError)
import Servant.API.Experimental.Auth (AuthProtect)
import Servant.Server.Experimental.Auth (AuthHandler, AuthServerData, mkAuthHandler)
import System.Environment (lookupEnv)

type instance AuthServerData (AuthProtect "crm-jwt") = CrmAuthResult

data CrmAuthResult
  = BffAuth { authSub :: Text, authCustomerId :: Maybe CustomerId }
  | InternalAuth

data CrmJwtConfig = CrmJwtConfig
  { cfgBffIssuer      :: Text
  , cfgBffJwksUri     :: String
  , cfgInternalIssuer :: Text
  , cfgIntJwksUri     :: String
  , cfgAudience       :: Text
  }

loadCrmJwtConfig :: IO CrmJwtConfig
loadCrmJwtConfig = do
  bffIss  <- getEnv "BFF_ISSUER"        "http://localhost:8081"
  bffJwks <- getEnv "BFF_JWKS_URI"      "http://localhost:8081/oauth/v2/keys"
  intIss  <- getEnv "INTERNAL_ISSUER"   "http://localhost:8081"
  intJwks <- getEnv "INTERNAL_JWKS_URI" "http://localhost:8081/oauth/v2/keys"
  aud     <- getEnv "JWT_AUDIENCE"      "https://hempire.com/crm-api"
  pure CrmJwtConfig
    { cfgBffIssuer      = T.pack bffIss
    , cfgBffJwksUri     = bffJwks
    , cfgInternalIssuer = T.pack intIss
    , cfgIntJwksUri     = intJwks
    , cfgAudience       = T.pack aud
    }
  where
    getEnv k d = maybe d id <$> lookupEnv k

makeCrmAuthHandler
  :: CrmJwtConfig -> IORef JWKSet -> IORef JWKSet -> AuthHandler Request CrmAuthResult
makeCrmAuthHandler cfg bffRef intRef = mkAuthHandler $ \req -> do
  token     <- extractBearer req
  bffKeys   <- liftIO (readIORef bffRef)
  bffResult <- liftIO (validateJwt bffKeys (cfgAudience cfg) (cfgBffIssuer cfg) token)
  case bffResult of
    Right claims -> pure (parseBffClaims claims)
    Left _       -> do
      intKeys   <- liftIO (readIORef intRef)
      intResult <- liftIO (validateJwt intKeys (cfgAudience cfg) (cfgInternalIssuer cfg) token)
      case intResult of
        Right _ -> pure InternalAuth
        Left _  -> throwError err401

extractBearer :: Request -> Handler Text
extractBearer req =
  case lookup "authorization" (requestHeaders req) of
    Just h | "Bearer " `BS.isPrefixOf` h -> pure (decodeUtf8 (BS.drop 7 h))
    _                                     -> throwError err401

parseBffClaims :: ClaimsSet -> CrmAuthResult
parseBffClaims claims =
  let sub  = maybe "" stringOrUriText (claims ^. claimSub)
      mCid = claims ^. unregisteredClaims . at customerIdClaim >>= \case
               A.String t -> case parseId t of
                 Right cid -> Just cid
                 Left _    -> Nothing
               _ -> Nothing
  in BffAuth{authSub = sub, authCustomerId = mCid}

customerIdClaim :: Text
customerIdClaim = "https://hempire.com/customer_id"

stringOrUriText :: StringOrURI -> Text
stringOrUriText sOrU = case A.toJSON sOrU of
  A.String t -> t
  _          -> ""
