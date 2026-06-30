module Crm.Types.IdpType (
  IdpType (..),
  parseIdpType,
  renderIdpType,
) where

import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text)
import GHC.Generics (Generic)

data IdpType = Zitadel
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

parseIdpType :: Text -> Either Text IdpType
parseIdpType "zitadel" = Right Zitadel
parseIdpType other = Left ("unknown idp type: " <> other)

renderIdpType :: IdpType -> Text
renderIdpType Zitadel = "zitadel"
