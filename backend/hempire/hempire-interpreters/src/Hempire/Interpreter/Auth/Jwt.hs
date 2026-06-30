module Hempire.Interpreter.Auth.Jwt (
  fetchJwks,
  validateJwt,
  extractIdentityId,
  extractCustomerIdText,
  hasZitadelRole,
) where

import Control.Lens ((^.))
import Control.Monad.Trans.Except (runExceptT)
import Crypto.JWT
import Data.Aeson (eitherDecode)
import Data.Aeson qualified as A
import Data.Aeson.Key qualified as AK
import Data.Aeson.KeyMap qualified as AKM
import Data.ByteString.Base64 qualified as B64
import Data.ByteString.Lazy qualified as BSL
import Data.String (IsString (..))
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding (decodeUtf8, encodeUtf8)
import Hempire.Identity (IdentityId (..))
import Network.HTTP.Client (httpLbs, parseRequest, responseBody)
import Network.HTTP.Client.TLS (tlsManagerSettings)
import OpenTelemetry.Instrumentation.HttpClient (httpClientInstrumentationConfig, newTracedManager)

fetchJwks :: String -> IO JWKSet
fetchJwks jwksUri = do
  mgr <- newTracedManager httpClientInstrumentationConfig tlsManagerSettings
  req <- parseRequest jwksUri
  resp <- httpLbs req mgr
  either (ioError . userError) pure $
    eitherDecode (responseBody resp)

validateJwt :: JWKSet -> Text -> Text -> Text -> IO (Either Text ClaimsSet)
validateJwt jwks audience issuer token = do
  let aud = fromString (T.unpack audience) :: StringOrURI
      iss = fromString (T.unpack issuer) :: StringOrURI
      settings = defaultJWTValidationSettings (== aud)
      bs = BSL.fromStrict (encodeUtf8 token)
  eJwt <- runExceptT @JWTError (decodeCompact bs)
  case eJwt of
    Left err -> pure (Left (T.pack (show err)))
    Right jwt -> do
      result <- runExceptT @JWTError (verifyClaims settings jwks jwt)
      pure $ case result of
        Left err -> Left (T.pack (show err))
        Right claims ->
          if claims ^. claimIss == Just iss
            then Right claims
            else Left "JWT issuer mismatch"

extractIdentityId :: ClaimsSet -> Maybe IdentityId
extractIdentityId claims = do
  issUri <- claims ^. claimIss
  subUri <- claims ^. claimSub
  pure
    IdentityId
      { identityIssuer = stringOrUriText issUri
      , identitySub = stringOrUriText subUri
      }

extractCustomerIdText :: ClaimsSet -> Maybe Text
extractCustomerIdText claims =
  case A.toJSON claims of
    A.Object obj ->
      case AKM.lookup (AK.fromText "urn:zitadel:iam:user:metadata") obj of
        Just (A.Object metaObj) ->
          case AKM.lookup (AK.fromText "customer_id") metaObj of
            Just (A.String encoded) ->
              either (const Nothing) (Just . decodeUtf8) $ B64.decode (encodeUtf8 encoded)
            _ -> Nothing
        _ -> Nothing
    _ -> Nothing

hasZitadelRole :: Text -> ClaimsSet -> Bool
hasZitadelRole roleName claims =
  case A.toJSON claims of
    A.Object obj ->
      case AKM.lookup (AK.fromText "urn:zitadel:iam:org:project:roles") obj of
        Just (A.Object rolesObj) -> AK.fromText roleName `AKM.member` rolesObj
        _ -> False
    _ -> False

stringOrUriText :: StringOrURI -> Text
stringOrUriText sOrU = case A.toJSON sOrU of
  A.String t -> t
  _ -> ""
