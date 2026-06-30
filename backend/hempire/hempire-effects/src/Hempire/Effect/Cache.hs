module Hempire.Effect.Cache (
  Cache (..),
  getCached,
  setCached,
  invalidateCache,
  getCachedJson,
  setCachedJson,
) where

import Data.Aeson (FromJSON, ToJSON, decode, encode)
import Data.ByteString (ByteString)
import Data.ByteString.Lazy qualified as BSL
import Data.Text (Text)
import Effectful
import Effectful.TH (makeEffect)

data Cache :: Effect where
  GetCached :: Text -> Cache m (Maybe ByteString)
  SetCached :: Text -> ByteString -> Int -> Cache m ()
  InvalidateCache :: Text -> Cache m ()

type instance DispatchOf Cache = Dynamic

makeEffect ''Cache

getCachedJson :: (FromJSON a, Cache :> es) => Text -> Eff es (Maybe a)
getCachedJson key = fmap (>>= decode . BSL.fromStrict) (getCached key)

setCachedJson :: (ToJSON a, Cache :> es) => Text -> a -> Int -> Eff es ()
setCachedJson key val ttl = setCached key (BSL.toStrict (encode val)) ttl
