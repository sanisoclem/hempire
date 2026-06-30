module Hempire.Effect.HempireError (HempireInternalError (..)) where

import Data.Text (Text)
import Hempire.Effect.Database (DatabaseError)

data HempireInternalError
  = DatabaseErr DatabaseError
  | DecodeErr Text
  deriving stock (Show)
