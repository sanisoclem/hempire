module Crm.Interpreter.Idp.Zitadel (
  ZitadelConfig (..),
  runIdpZitadel,
) where

import Control.Monad (unless)
import Crm.Core.Idp (Idp (..), IdpUserInfo (..))
import Data.Aeson (FromJSON (..), eitherDecode, encode, object, withObject, (.:), (.=))
import Data.Aeson.Types (parseEither)
import Data.ByteString.Base64 qualified as B64
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding (decodeUtf8, encodeUtf8)
import Effectful
import Effectful.Dispatch.Dynamic
import Hempire.DomainId (showId)
import Network.HTTP.Client
import Network.HTTP.Client.TLS (tlsManagerSettings)
import Network.HTTP.Types (statusIsSuccessful)
import OpenTelemetry.Instrumentation.HttpClient (httpClientInstrumentationConfig, newTracedManager)

data ZitadelConfig = ZitadelConfig
  { zCfgApiUrl :: Text
  , zCfgClientId :: Text
  , zCfgClientSecret :: Text
  }

newtype TokenResponse = TokenResponse Text

instance FromJSON TokenResponse where
  parseJSON = withObject "TokenResponse" $ \o ->
    TokenResponse <$> o .: "access_token"

runIdpZitadel :: (IOE :> es) => ZitadelConfig -> Eff (Idp : es) a -> Eff es a
runIdpZitadel cfg = interpret $ \_env -> \case
  SetIdentityCustomer "zitadel" identId cid ->
    liftIO $ do
      mgr <- newTracedManager httpClientInstrumentationConfig tlsManagerSettings
      token <- fetchServiceToken cfg mgr
      setUserCustomerId cfg mgr token identId (showId cid)
  SetIdentityCustomer other _ _ ->
    liftIO $ ioError (userError ("runIdpZitadel: unknown idp type: " <> T.unpack other))
  GetUserInfo "zitadel" identId ->
    liftIO $ do
      mgr <- newTracedManager httpClientInstrumentationConfig tlsManagerSettings
      token <- fetchServiceToken cfg mgr
      fetchUserEmail cfg mgr token identId
  GetUserInfo other _ ->
    liftIO $ ioError (userError ("runIdpZitadel: unknown idp type: " <> T.unpack other))

fetchServiceToken :: ZitadelConfig -> Manager -> IO Text
fetchServiceToken cfg mgr = do
  req <- parseRequest (T.unpack (zCfgApiUrl cfg) <> "/oauth/v2/token")
  let req' =
        urlEncodedBody
          [ ("grant_type", "client_credentials")
          , ("client_id", encodeUtf8 (zCfgClientId cfg))
          , ("client_secret", encodeUtf8 (zCfgClientSecret cfg))
          , ("scope", "openid urn:zitadel:iam:org:project:id:zitadel:aud")
          ]
          req
  resp <- httpLbs req' mgr
  case eitherDecode (responseBody resp) of
    Left err -> ioError (userError ("Zitadel token error: " <> err))
    Right (TokenResponse tok) -> pure tok

setUserCustomerId :: ZitadelConfig -> Manager -> Text -> Text -> Text -> IO ()
setUserCustomerId cfg mgr token identId cidText = do
  let url =
        T.unpack (zCfgApiUrl cfg)
          <> "/management/v1/users/"
          <> T.unpack identId
          <> "/metadata/customer_id"
      body = encode (object ["value" .= encodeMetaValue cidText])
  req <- parseRequest url
  let req' =
        req
          { method = "POST"
          , requestBody = RequestBodyLBS body
          , requestHeaders =
              [ ("Content-Type", "application/json")
              , ("Authorization", "Bearer " <> encodeUtf8 token)
              ]
          }
  resp <- httpLbs req' mgr
  unless (statusIsSuccessful (responseStatus resp)) $
    ioError (userError ("Zitadel metadata error: " <> show (responseStatus resp)))

fetchUserEmail :: ZitadelConfig -> Manager -> Text -> Text -> IO IdpUserInfo
fetchUserEmail cfg mgr token identId = do
  let url = T.unpack (zCfgApiUrl cfg) <> "/management/v1/users/" <> T.unpack identId
  req <- parseRequest url
  let req' =
        req
          { requestHeaders =
              [ ("Content-Type", "application/json")
              , ("Authorization", "Bearer " <> encodeUtf8 token)
              ]
          }
  resp <- httpLbs req' mgr
  unless (statusIsSuccessful (responseStatus resp)) $
    ioError (userError ("Zitadel get user error: " <> show (responseStatus resp)))
  case eitherDecode (responseBody resp) of
    Left err -> ioError (userError ("Zitadel get user parse error: " <> err))
    Right v -> case parseEither parseEmail v of
      Left err -> ioError (userError ("Zitadel get user email missing: " <> err))
      Right email -> pure (IdpUserInfo email)
 where
  parseEmail = withObject "GetUserResponse" $ \o ->
    o .: "user" >>= \user ->
      user .: "human" >>= \human ->
        human .: "email" >>= \emailObj ->
          emailObj .: "email"

encodeMetaValue :: Text -> Text
encodeMetaValue t = decodeUtf8 (B64.encode (encodeUtf8 t))
