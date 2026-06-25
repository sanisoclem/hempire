module Crm.Types.Response
  ( CrmError (..)
  , CrmResponse (..)
  , OnboardingStatus (..)
  ) where

import Data.Aeson
  ( FromJSON (..)
  , Options (..)
  , SumEncoding (..)
  , ToJSON (..)
  , defaultOptions
  , genericParseJSON
  , genericToEncoding
  , genericToJSON
  )
import Data.Text (Text)
import GHC.Generics (Generic)
import Hempire.Id (CustomerId (..))

data CrmError
  = NotFound Text
  | ValidationFailed [Text]
  | Conflict Text
  | InviteAlreadyClaimed Text
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data CrmResponse a
  = Ok a
  | Err CrmError
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data OnboardingStatus
  = NotOnboarded
  | OnboardingPending
  | Onboarded { customerId :: CustomerId }
  deriving stock (Show, Eq, Generic)

onboardingStatusOptions :: Options
onboardingStatusOptions =
  defaultOptions
    { sumEncoding = TaggedObject{tagFieldName = "status", contentsFieldName = "data"} }

instance FromJSON OnboardingStatus where
  parseJSON = genericParseJSON onboardingStatusOptions

instance ToJSON OnboardingStatus where
  toJSON     = genericToJSON     onboardingStatusOptions
  toEncoding = genericToEncoding onboardingStatusOptions
