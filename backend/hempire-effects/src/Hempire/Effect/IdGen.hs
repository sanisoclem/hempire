module Hempire.Effect.IdGen
  ( -- * Effect
    IdGen (..)
    -- * Operations
  , newId
  , deriveId
  ) where

import Data.Text (Text)
import Effectful
import Effectful.TH (makeEffect)

-- | Effect for ID generation.
-- 'NewId' produces a fresh random identifier (UUID v4, no hyphens).
-- 'DeriveId' deterministically derives an identifier from input text
-- via SHA-256 followed by Base58Check encoding — used to generate a
-- 'CustomerId' from an 'InviteId' so a single invite can only ever
-- produce one customer.
data IdGen :: Effect where
  NewId    :: IdGen m Text
  DeriveId :: Text -> IdGen m Text

type instance DispatchOf IdGen = Dynamic

makeEffect ''IdGen
