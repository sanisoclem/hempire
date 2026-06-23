module Ledger.Types
  ( -- * Command envelope
    LedgerCommand (..)
    -- * Commands
  , PostEntry (..)
    -- * Events
  , EntryPosted (..)
    -- * Responses
  , LedgerResponse (..)
  , LedgerError (..)
  , EntryId (..)
  , AccountId (..)
  , Amount (..)
  ) where

import Data.Aeson
  ( FromJSON (..), Options (..), SumEncoding (..), ToJSON (..)
  , defaultOptions, genericParseJSON, genericToEncoding, genericToJSON
  )
import Data.Text (Text)
import Data.Time (UTCTime)
import GHC.Generics (Generic)

-- | All commands this domain accepts on the @ledger.commands@ topic.
data LedgerCommand
  = PostEntryCommand PostEntry
  deriving stock (Show, Eq, Generic)

commandOptions :: Options
commandOptions = defaultOptions
  { sumEncoding = TaggedObject { tagFieldName = "type", contentsFieldName = "payload" } }

instance FromJSON LedgerCommand where
  parseJSON = genericParseJSON commandOptions

instance ToJSON LedgerCommand where
  toJSON     = genericToJSON commandOptions
  toEncoding = genericToEncoding commandOptions

newtype EntryId   = EntryId Text   deriving stock (Show, Eq, Generic) deriving anyclass (FromJSON, ToJSON)
newtype AccountId = AccountId Text deriving stock (Show, Eq, Ord, Generic) deriving anyclass (FromJSON, ToJSON)

-- | Monetary amount stored as integer cents to avoid floating-point issues.
newtype Amount = Amount { unAmount :: Int }
  deriving stock (Show, Eq, Ord, Generic)
  deriving anyclass (FromJSON, ToJSON)

data PostEntry = PostEntry
  { peDebit         :: AccountId
  , peCredit        :: AccountId
  , peAmount        :: Amount
  , peDescription   :: Text
  , peCorrelationId :: Text
  }
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data EntryPosted = EntryPosted
  { epEvtId            :: EntryId
  , epEvtDebit         :: AccountId
  , epEvtCredit        :: AccountId
  , epEvtAmount        :: Amount
  , epEvtCorrelationId :: Text
  , epEvtAt            :: UTCTime
  }
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data LedgerError
  = AccountNotFound AccountId
  | InsufficientFunds AccountId Amount
  | ValidationFailed [Text]
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data LedgerResponse a
  = Ok a
  | Err LedgerError
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)
