module Hempire.Interpreter.Auth.Jwt
  ( fetchJwks
  , validateJwt
  ) where

import Control.Lens ((^.))
import Control.Monad.Trans.Except (runExceptT)
import Crypto.JOSE.JWK (JWKSet (..))
import Crypto.JWT
import Data.Aeson (eitherDecode)
import Data.Aeson qualified as A
import Data.ByteString.Lazy qualified as BSL
import Data.String (IsString (..))
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding (encodeUtf8)
import Network.HTTP.Client (httpLbs, parseRequest, responseBody)
import Network.HTTP.Client.TLS (newTlsManager)

fetchJwks :: String -> IO JWKSet
fetchJwks uri = do
  mgr  <- newTlsManager
  req  <- parseRequest uri
  resp <- httpLbs req mgr
  either (ioError . userError) pure $
    eitherDecode (responseBody resp)

validateJwt :: JWKSet -> Text -> Text -> Text -> IO (Either Text ClaimsSet)
validateJwt jwks audience issuer token = do
  let aud      = fromString (T.unpack audience) :: StringOrURI
      iss      = fromString (T.unpack issuer)   :: StringOrURI
      settings = defaultJWTValidationSettings (== aud)
      bs       = BSL.fromStrict (encodeUtf8 token)
  eJwt <- runExceptT @JWTError (decodeCompact bs)
  case eJwt of
    Left err  -> pure (Left (T.pack (show err)))
    Right jwt -> do
      result <- runExceptT @JWTError (verifyClaims settings jwks jwt)
      pure $ case result of
        Left err    -> Left (T.pack (show err))
        Right claims ->
          if claims ^. claimIss == Just iss
            then Right claims
            else Left "JWT issuer mismatch"

stringOrUriText :: StringOrURI -> Text
stringOrUriText sOrU = case A.toJSON sOrU of
  A.String t -> t
  _          -> ""
