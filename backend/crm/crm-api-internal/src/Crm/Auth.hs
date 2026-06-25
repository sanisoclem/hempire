-- see: https://github.com/haskell-servant/servant/blob/5a6f794d01b55633b226c378551cfea5ca882090/doc/tutorial/Authentication.lhs#L396
{-# OPTIONS_GHC -Wno-orphans #-}
module Crm.Auth
  ( InternalAuth (..)
  , InternalJwtConfig (..)
  , loadInternalJwtConfig
  , makeInternalAuthHandler
  ) where

import Control.Monad.IO.Class (liftIO)
import Crypto.JOSE.JWK (JWKSet)
import Data.ByteString qualified as BS
import Data.IORef (IORef, readIORef)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding (decodeUtf8)
import Hempire.Identity (IdentityId)
import Hempire.Interpreter.Auth.Jwt
  ( extractIdentityId
  , hasZitadelRole
  , validateJwt
  )
import Network.Wai (Request, requestHeaders)
import Servant (Handler, err401, err403, throwError)
import Servant.API.Experimental.Auth (AuthProtect)
import Servant.Server.Experimental.Auth (AuthHandler, AuthServerData, mkAuthHandler)
import System.Environment (lookupEnv)

type instance AuthServerData (AuthProtect "crm-internal") = InternalAuth

-- | Validated internal caller identity.
newtype InternalAuth = InternalAuth
  { iAuthIdentity :: IdentityId }

data InternalJwtConfig = InternalJwtConfig
  { cfgJwksUri      :: String
  , cfgIssuer       :: Text
  , cfgAudience     :: Text  -- Hempire Internal project Resource ID in internal Zitadel
  , cfgRequiredRole :: Text  -- e.g. "CRM-API"
  }

loadInternalJwtConfig :: IO InternalJwtConfig
loadInternalJwtConfig = do
  jwksUri  <- getEnv "CRM_INTERNAL_JWKS_URI"      "http://localhost:8082/oauth/v2/keys"
  issuer   <- getEnv "CRM_INTERNAL_ISSUER"         "http://localhost:8082"
  audience <- getEnv "CRM_INTERNAL_AUDIENCE"       ""
  role     <- getEnv "CRM_INTERNAL_REQUIRED_ROLE"  "CRM-API"
  pure InternalJwtConfig
    { cfgJwksUri      = jwksUri
    , cfgIssuer       = T.pack issuer
    , cfgAudience     = T.pack audience
    , cfgRequiredRole = T.pack role
    }
  where
    getEnv k d = maybe d id <$> lookupEnv k

makeInternalAuthHandler
  :: InternalJwtConfig -> IORef JWKSet -> AuthHandler Request InternalAuth
makeInternalAuthHandler cfg keysRef = mkAuthHandler $ \req -> do
  token  <- extractBearer req
  keys   <- liftIO (readIORef keysRef)
  result <- liftIO (validateJwt keys (cfgAudience cfg) (cfgIssuer cfg) token)
  case result of
    Left _       -> throwError err401
    Right claims -> do
      unless (hasZitadelRole (cfgRequiredRole cfg) claims) $
        throwError err403
      case extractIdentityId claims of
        Nothing       -> throwError err401
        Just identity -> pure (InternalAuth identity)
  where
    unless cond action = if cond then pure () else action

extractBearer :: Request -> Handler Text
extractBearer req =
  case lookup "authorization" (requestHeaders req) of
    Just h | "Bearer " `BS.isPrefixOf` h -> pure (decodeUtf8 (BS.drop 7 h))
    _                                     -> throwError err401
