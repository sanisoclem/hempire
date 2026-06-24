module Hempire.Effect.Events
  ( -- * Effect
    Events (..)
    -- * Operations
  , publishEvent
    -- * Types
  , TopicName (..)
  ) where

import Data.Aeson (ToJSON)
import Data.String (IsString)
import Data.Text (Text)
import Effectful
import Effectful.Dispatch.Dynamic
import Effectful.TH (makeEffect)

newtype TopicName = TopicName { unTopicName :: Text }
  deriving stock (Show, Eq, Ord)
  deriving newtype (IsString)

data Events :: Effect where
  PublishEvent :: ToJSON a => TopicName -> a -> Events m ()

type instance DispatchOf Events = Dynamic

makeEffect ''Events
