module Crm.Types
  ( -- * Domain IDs
    CustomerId (..)
  , InviteId (..)
  , IdentityProviderId (..)

    -- * Identity provider
  , IdentityProvider (..)

    -- * Invite
  , InviteSource (..)
  , InviteDetails (..)

    -- * Identity
  , Identity (..)

    -- * Onboarding status
  , OnboardingStatus (..)

    -- * Commands (inputs)
  , OnboardCustomer (..)
  , CreateInvite (..)
  , DeleteCustomerInvite (..)
  , DeactivateCustomer (..)

    -- * Kafka command envelope
  , CrmCommand (..)

    -- * Events
  , CustomerOnboarded (..)
  , InviteCreated (..)
  , InviteDeleted (..)
  , CustomerDeactivated (..)

    -- * Responses
  , CrmResponse (..)
  , CrmError (..)
  ) where

import Data.Aeson (
    FromJSON (..),
    Options (..),
    SumEncoding (..),
    ToJSON (..),
    defaultOptions,
    genericParseJSON,
    genericToEncoding,
    genericToJSON,
 )
import Data.Text (Text)
import Data.Time (UTCTime)
import GHC.Generics (Generic)
import Hempire.DomainId (makeDomainId)
import Optics.TH (makeFieldLabelsNoPrefix)

-- --------------------------------------------------------------------------
-- Domain IDs
-- --------------------------------------------------------------------------

makeDomainId "CustomerId"         "cust_"
makeDomainId "InviteId"           "inv_"
makeDomainId "IdentityProviderId" "idp_"

-- --------------------------------------------------------------------------
-- Identity provider enum (used for configuration, not DB lookup by ID)
-- --------------------------------------------------------------------------

data IdentityProvider
    = DebugIdentityProvider
    | ClerkIdentityProvider
    deriving stock (Show, Eq, Generic)
    deriving anyclass (FromJSON, ToJSON)

-- --------------------------------------------------------------------------
-- Invite
-- --------------------------------------------------------------------------

data InviteSource
    = Referral
    | Waitlist
    | Debug
    | Manual
    deriving stock (Show, Eq, Generic)
    deriving anyclass (FromJSON, ToJSON)

data InviteDetails = InviteDetails
    { inviteId   :: InviteId
    , source     :: InviteSource
    , createdOn  :: UTCTime
    , active     :: Bool
    , customerId :: Maybe CustomerId
    , comment    :: Maybe Text
    }
    deriving stock (Show, Eq, Generic)
    deriving anyclass (FromJSON, ToJSON)

makeFieldLabelsNoPrefix ''InviteDetails

-- --------------------------------------------------------------------------
-- Identity
-- --------------------------------------------------------------------------

data Identity = Identity
    { providerId :: IdentityProviderId
    , identityId :: Text
    }
    deriving stock (Show, Eq, Generic)
    deriving anyclass (FromJSON, ToJSON)

makeFieldLabelsNoPrefix ''Identity

-- --------------------------------------------------------------------------
-- Onboarding status
-- --------------------------------------------------------------------------

data OnboardingStatus
    = NotOnboarded
    | OnboardingPending
    | Onboarded {customerId :: CustomerId}
    deriving stock (Show, Eq, Generic)

onboardingStatusOptions :: Options
onboardingStatusOptions =
    defaultOptions
        { sumEncoding = TaggedObject{tagFieldName = "status", contentsFieldName = "data"}
        }

instance FromJSON OnboardingStatus where
    parseJSON = genericParseJSON onboardingStatusOptions

instance ToJSON OnboardingStatus where
    toJSON     = genericToJSON     onboardingStatusOptions
    toEncoding = genericToEncoding onboardingStatusOptions

-- --------------------------------------------------------------------------
-- Command inputs
-- --------------------------------------------------------------------------

data OnboardCustomer = OnboardCustomer
    { identity :: Identity
    , inviteId :: InviteId
    }
    deriving stock (Show, Eq, Generic)
    deriving anyclass (FromJSON, ToJSON)

makeFieldLabelsNoPrefix ''OnboardCustomer

data CreateInvite = CreateInvite
    { source  :: InviteSource
    , comment :: Maybe Text
    }
    deriving stock (Show, Eq, Generic)
    deriving anyclass (FromJSON, ToJSON)

makeFieldLabelsNoPrefix ''CreateInvite

newtype DeleteCustomerInvite = DeleteCustomerInvite
    { inviteId :: InviteId
    }
    deriving stock (Show, Eq, Generic)
    deriving anyclass (FromJSON, ToJSON)

makeFieldLabelsNoPrefix ''DeleteCustomerInvite

newtype DeactivateCustomer = DeactivateCustomer
    { customerId :: CustomerId
    }
    deriving stock (Show, Eq, Generic)
    deriving anyclass (FromJSON, ToJSON)

makeFieldLabelsNoPrefix ''DeactivateCustomer

-- --------------------------------------------------------------------------
-- Kafka command envelope (state-mutating operations only)
-- --------------------------------------------------------------------------

data CrmCommand
    = OnboardCustomerCommand OnboardCustomer
    | CreateInviteCommand CreateInvite
    | DeleteCustomerInviteCommand DeleteCustomerInvite
    | DeactivateCustomerCommand DeactivateCustomer
    deriving stock (Show, Eq, Generic)

commandOptions :: Options
commandOptions =
    defaultOptions
        { sumEncoding = TaggedObject{tagFieldName = "type", contentsFieldName = "payload"}
        }

instance FromJSON CrmCommand where
    parseJSON = genericParseJSON commandOptions

instance ToJSON CrmCommand where
    toJSON     = genericToJSON     commandOptions
    toEncoding = genericToEncoding commandOptions

-- --------------------------------------------------------------------------
-- Events
-- --------------------------------------------------------------------------

data CustomerOnboarded = CustomerOnboarded
    { customerId :: CustomerId
    , inviteId   :: InviteId
    , identity   :: Identity
    , at         :: UTCTime
    }
    deriving stock (Show, Eq, Generic)
    deriving anyclass (FromJSON, ToJSON)

makeFieldLabelsNoPrefix ''CustomerOnboarded

data InviteCreated = InviteCreated
    { inviteId :: InviteId
    , source   :: InviteSource
    , at       :: UTCTime
    }
    deriving stock (Show, Eq, Generic)
    deriving anyclass (FromJSON, ToJSON)

makeFieldLabelsNoPrefix ''InviteCreated

data InviteDeleted = InviteDeleted
    { inviteId :: InviteId
    , at       :: UTCTime
    }
    deriving stock (Show, Eq, Generic)
    deriving anyclass (FromJSON, ToJSON)

makeFieldLabelsNoPrefix ''InviteDeleted

data CustomerDeactivated = CustomerDeactivated
    { customerId :: CustomerId
    , at         :: UTCTime
    }
    deriving stock (Show, Eq, Generic)
    deriving anyclass (FromJSON, ToJSON)

makeFieldLabelsNoPrefix ''CustomerDeactivated

-- --------------------------------------------------------------------------
-- Responses
-- --------------------------------------------------------------------------

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
