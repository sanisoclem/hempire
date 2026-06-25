-- see: https://github.com/haskell-servant/servant/blob/5a6f794d01b55633b226c378551cfea5ca882090/doc/tutorial/Authentication.lhs#L396
{-# OPTIONS_GHC -Wno-orphans #-}

module Crm.Auth (
    InternalAuth (..),
    InternalJwtConfig (..),
    loadInternalJwtConfig,
    makeInternalAuthHandler,
) where

import Control.Monad (unless)
import Control.Monad.IO.Class (liftIO)
import Crypto.JOSE.JWK (JWKSet)
import Data.ByteString qualified as BS
import Data.IORef (IORef, readIORef)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding (decodeUtf8)
import Hempire.Identity (IdentityId)
import Hempire.Interpreter.Auth.Jwt (
    extractIdentityId,
    hasZitadelRole,
    validateJwt,
 )
import Network.Wai (Request, requestHeaders)
import Servant (Handler, err401, err403, throwError)
import Servant.API.Experimental.Auth (AuthProtect)
import Servant.Server.Experimental.Auth (AuthHandler, AuthServerData, mkAuthHandler)
import System.Environment (lookupEnv)

type instance AuthServerData (AuthProtect "crm-internal") = InternalAuth

newtype InternalAuth = InternalAuth
    {iAuthIdentity :: IdentityId}

data InternalJwtConfig = InternalJwtConfig
    { cfgJwksUri :: String
    , cfgIssuer :: Text
    , cfgAudience :: Text
    , cfgRequiredRole :: Text
    }

loadInternalJwtConfig :: IO InternalJwtConfig
loadInternalJwtConfig = do
    jwksUri <- requireEnv "AUTH_INTERNAL_JWKS_URI"
    issuer <- requireEnv "AUTH_INTERNAL_ISSUER"
    audience <- requireEnv "AUTH_INTERNAL_AUDIENCE"
    role <- requireEnv "CRM_AUTH_INTERNAL_REQUIRED_ROLE"
    pure
        InternalJwtConfig
            { cfgJwksUri = jwksUri
            , cfgIssuer = T.pack issuer
            , cfgAudience = T.pack audience
            , cfgRequiredRole = T.pack role
            }

makeInternalAuthHandler ::
    InternalJwtConfig -> IORef JWKSet -> AuthHandler Request InternalAuth
makeInternalAuthHandler cfg keysRef = mkAuthHandler $ \req -> do
    token <- extractBearer req
    keys <- liftIO (readIORef keysRef)
    result <- liftIO (validateJwt keys (cfgAudience cfg) (cfgIssuer cfg) token)
    case result of
        Left _ -> throwError err401
        Right claims -> do
            unless (hasZitadelRole (cfgRequiredRole cfg) claims) $
                throwError err403
            case extractIdentityId claims of
                Nothing -> throwError err401
                Just identity -> pure (InternalAuth identity)

extractBearer :: Request -> Handler Text
extractBearer req =
    case lookup "authorization" (requestHeaders req) of
        Just h | "Bearer " `BS.isPrefixOf` h -> pure (decodeUtf8 (BS.drop 7 h))
        _ -> throwError err401

requireEnv :: String -> IO String
requireEnv k = lookupEnv k >>= maybe (fail ("required env var not set: " <> k)) pure
