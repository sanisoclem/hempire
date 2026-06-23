module Crm.Types
  ( -- * Command envelope
    CrmCommand (..)
    -- * Commands
  , CreateContact (..)
  , UpdateContact (..)
    -- * Events
  , ContactCreated (..)
  , ContactUpdated (..)
    -- * Responses
  , CrmResponse (..)
  , CrmError (..)
  , ContactId (..)
  ) where

import Data.Aeson
  ( FromJSON (..), Options (..), SumEncoding (..), ToJSON (..)
  , defaultOptions, genericParseJSON, genericToEncoding, genericToJSON
  )
import Data.Text (Text)
import Data.Time (UTCTime)
import GHC.Generics (Generic)

-- | All commands this domain accepts on the @crm.commands@ topic.
data CrmCommand
  = CreateContactCommand CreateContact
  | UpdateContactCommand UpdateContact
  deriving stock (Show, Eq, Generic)

commandOptions :: Options
commandOptions = defaultOptions
  { sumEncoding = TaggedObject { tagFieldName = "type", contentsFieldName = "payload" } }

instance FromJSON CrmCommand where
  parseJSON = genericParseJSON commandOptions

instance ToJSON CrmCommand where
  toJSON     = genericToJSON commandOptions
  toEncoding = genericToEncoding commandOptions

newtype ContactId = ContactId Text
  deriving stock (Show, Eq, Ord, Generic)
  deriving anyclass (FromJSON, ToJSON)

data CreateContact = CreateContact
  { ccName          :: Text
  , ccEmail         :: Text
  , ccCorrelationId :: Text
  }
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data UpdateContact = UpdateContact
  { ucId            :: ContactId
  , ucName          :: Maybe Text
  , ucEmail         :: Maybe Text
  , ucCorrelationId :: Text
  }
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data ContactCreated = ContactCreated
  { ccEvtId            :: ContactId
  , ccEvtName          :: Text
  , ccEvtEmail         :: Text
  , ccEvtCorrelationId :: Text
  , ccEvtAt            :: UTCTime
  }
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data ContactUpdated = ContactUpdated
  { cuEvtId            :: ContactId
  , cuEvtCorrelationId :: Text
  , cuEvtAt            :: UTCTime
  }
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data CrmError
  = NotFound Text
  | ValidationFailed [Text]
  | Conflict Text
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data CrmResponse a
  = Ok a
  | Err CrmError
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)
