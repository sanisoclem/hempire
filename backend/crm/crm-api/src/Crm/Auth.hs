-- see: https://github.com/haskell-servant/servant/blob/5a6f794d01b55633b226c378551cfea5ca882090/doc/tutorial/Authentication.lhs#L396
{-# OPTIONS_GHC -Wno-orphans #-}

module Crm.Auth (
  CustomerAuth (..),
  JwtConfig (..),
  loadCustomerJwtConfig,
  makeCustomerAuthHandler,
) where

import Control.Monad.IO.Class (liftIO)
import Crypto.JOSE.JWK (JWKSet)
import Data.ByteString qualified as BS
import Data.IORef (IORef, readIORef)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding (decodeUtf8)
import Hempire.DomainId (parseId)
import Hempire.Id (CustomerId)
import Hempire.Identity (IdentityId)
import Hempire.Interpreter.Auth.Jwt (
  extractCustomerIdText,
  extractIdentityId,
  validateJwt,
 )
import Network.Wai (Request, requestHeaders)
import Servant (Handler, err401, throwError)
import Servant.API.Experimental.Auth (AuthProtect)
import Servant.Server.Experimental.Auth (AuthHandler, AuthServerData, mkAuthHandler)
import System.Environment (lookupEnv)

data CustomerAuth = CustomerAuth
  { cauthIdentity :: IdentityId
  , cauthCustomerId :: Maybe CustomerId
  }

type instance AuthServerData (AuthProtect "crm-customer") = CustomerAuth

data JwtConfig = JwtConfig
  { cfgJwksUri :: String
  , cfgIssuer :: Text
  , cfgAudience :: Text
  }

loadCustomerJwtConfig :: IO JwtConfig
loadCustomerJwtConfig = do
  jwksUri <- requireEnv "AUTH_JWKS_URI"
  issuer <- requireEnv "AUTH_ISSUER"
  audience <- requireEnv "AUTH_AUDIENCE"
  pure
    JwtConfig
      { cfgJwksUri = jwksUri
      , cfgIssuer = T.pack issuer
      , cfgAudience = T.pack audience
      }

makeCustomerAuthHandler ::
  JwtConfig -> IORef JWKSet -> AuthHandler Request CustomerAuth
makeCustomerAuthHandler cfg keysRef = mkAuthHandler $ \req -> do
  token <- extractBearer req
  keys <- liftIO (readIORef keysRef)
  result <- liftIO (validateJwt keys (cfgAudience cfg) (cfgIssuer cfg) token)
  case result of
    Left _ -> throwError err401
    Right claims ->
      case extractIdentityId claims of
        Nothing -> throwError err401
        Just identity ->
          let mCid = extractCustomerIdText claims >>= either (const Nothing) Just . parseId
           in pure CustomerAuth {cauthIdentity = identity, cauthCustomerId = mCid}

extractBearer :: Request -> Handler Text
extractBearer req =
  case lookup "authorization" (requestHeaders req) of
    Just h | "Bearer " `BS.isPrefixOf` h -> pure (decodeUtf8 (BS.drop 7 h))
    _ -> throwError err401

requireEnv :: String -> IO String
requireEnv k = lookupEnv k >>= maybe (fail ("required env var not set: " <> k)) pure
