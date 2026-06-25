{-# LANGUAGE UndecidableInstances #-}
-- | Platform-wide identity: who authenticated the request.
module Hempire.Identity
  ( IdentityId (..)
  ) where

import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text)
import GHC.Generics (Generic)
import Optics.TH (makeFieldLabelsNoPrefix)

-- | The authenticated identity from a JWT.
-- 'identityIssuer' is the @iss@ claim, which equals @identity_provider_id@ in postgres.
-- 'identitySub' is the @sub@ claim — the user's ID within that Zitadel instance.
-- Represents any principal: customer, employee, or service account.
data IdentityId = IdentityId
  { identityIssuer :: Text
  , identitySub    :: Text
  } deriving stock (Eq, Ord, Show, Generic)
    deriving anyclass (FromJSON, ToJSON)

makeFieldLabelsNoPrefix ''IdentityId
