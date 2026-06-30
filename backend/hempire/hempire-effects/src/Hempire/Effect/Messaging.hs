module Hempire.Effect.Messaging (Messaging (..), sendMessage) where

import Data.ByteString (ByteString)
import Data.Text (Text)
import Effectful
import Effectful.TH (makeEffect)

data Messaging :: Effect where
  SendMessage :: Text -> ByteString -> Messaging m ()

type instance DispatchOf Messaging = Dynamic

makeEffect ''Messaging
