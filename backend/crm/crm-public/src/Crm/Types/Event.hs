module Crm.Types.Event (
  CustomerOnboarded (..),
  InviteCreated (..),
  InviteDeleted (..),
  CustomerStatusChanged (..),
  CrmEvent (..),
) where

import Crm.Types.Invite (InviteId, InviteSource)
import Data.Aeson (FromJSON, ToJSON (..), Value (..))
import Data.Aeson qualified as A
import Data.Aeson.KeyMap qualified as KM
import Data.Aeson.Key qualified as AK
import Data.Text (Text)
import Data.Time (UTCTime)
import GHC.Generics (Generic)
import Hempire.Id (CustomerId (..))
import Optics.TH (makeFieldLabelsNoPrefix)

data CustomerOnboarded = CustomerOnboarded
  { customerId :: CustomerId
  , inviteId :: InviteId
  , friendlyName :: Text
  , identityId :: Text
  , at :: UTCTime
  }
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

makeFieldLabelsNoPrefix ''CustomerOnboarded

data InviteCreated = InviteCreated
  { inviteId :: InviteId
  , source :: InviteSource
  , at :: UTCTime
  }
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

makeFieldLabelsNoPrefix ''InviteCreated

data InviteDeleted = InviteDeleted
  { inviteId :: InviteId
  , at :: UTCTime
  }
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

makeFieldLabelsNoPrefix ''InviteDeleted

data CustomerStatusChanged = CustomerStatusChanged
  { customerId :: CustomerId
  , active :: Bool
  , at :: UTCTime
  }
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

makeFieldLabelsNoPrefix ''CustomerStatusChanged

data CrmEvent
  = CrmCustomerOnboarded CustomerOnboarded
  | CrmInviteCreated InviteCreated
  | CrmInviteDeleted InviteDeleted
  | CrmCustomerStatusChanged CustomerStatusChanged
  deriving stock (Show, Eq, Generic)

instance ToJSON CrmEvent where
  toJSON = \case
    CrmCustomerOnboarded x -> taggedJson "CustomerOnboarded" x
    CrmInviteCreated x -> taggedJson "InviteCreated" x
    CrmInviteDeleted x -> taggedJson "InviteDeleted" x
    CrmCustomerStatusChanged x -> taggedJson "CustomerStatusChanged" x

taggedJson :: (ToJSON a) => Text -> a -> Value
taggedJson tag x = case toJSON x of
  Object o -> Object (KM.insert (AK.fromText "eventType") (A.String tag) o)
  v -> v
