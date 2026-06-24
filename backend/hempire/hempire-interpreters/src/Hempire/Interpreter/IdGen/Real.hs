module Hempire.Interpreter.IdGen.Real
  ( runIdGenReal
  ) where

import Crypto.Hash.SHA256 qualified as SHA256
import Data.ByteString (ByteString)
import Data.ByteString qualified as BS
import Data.List (unfoldr)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding (decodeUtf8, encodeUtf8)
import Data.UUID qualified as UUID
import Data.UUID.V4 qualified as UUID.V4
import Effectful
import Effectful.Dispatch.Dynamic

import Hempire.Effect.IdGen (IdGen (..))

runIdGenReal :: IOE :> es => Eff (IdGen : es) a -> Eff es a
runIdGenReal = interpret $ \_env -> \case
  NewId      -> liftIO $ T.filter (/= '-') . T.pack . UUID.toString <$> UUID.V4.nextRandom
  DeriveId t -> pure $ base58Check (SHA256.hash (encodeUtf8 t))

-- | Base58Check encode a ByteString.
-- Checksum = first 4 bytes of SHA256(SHA256(payload)).
-- Result is Base58-encoded (payload ++ checksum).
base58Check :: ByteString -> Text
base58Check payload =
  let chk    = BS.take 4 (SHA256.hash (SHA256.hash payload))
      full   = payload <> chk
      leadingZeros = BS.length (BS.takeWhile (== 0) full)
      encoded = encodeBase58 full
  in decodeUtf8 (BS.replicate leadingZeros 49 <> encoded)  -- '1' = 49

alphabet :: ByteString
alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

encodeBase58 :: ByteString -> ByteString
encodeBase58 bs =
  let n       = bytesToInteger bs
      digits  = reverse $ unfoldr step n
      step 0  = Nothing
      step k  = let (q, r) = k `divMod` 58
                in  Just (BS.index alphabet (fromIntegral r), q)
  in BS.pack digits

bytesToInteger :: ByteString -> Integer
bytesToInteger = BS.foldl' (\acc b -> acc * 256 + fromIntegral b) 0
