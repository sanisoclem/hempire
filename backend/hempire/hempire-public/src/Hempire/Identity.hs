{-# LANGUAGE UndecidableInstances #-}

module Hempire.Identity (
  IdentityId (..),
  formatIdentityId,
) where

import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text)
import GHC.Generics (Generic)
import Optics.TH (makeFieldLabelsNoPrefix)

data IdentityId = IdentityId
  { identityIssuer :: Text
  , identitySub :: Text
  }
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (FromJSON, ToJSON)

makeFieldLabelsNoPrefix ''IdentityId

formatIdentityId :: IdentityId -> Text
formatIdentityId IdentityId{identityIssuer, identitySub} = identityIssuer <> "|" <> identitySub
