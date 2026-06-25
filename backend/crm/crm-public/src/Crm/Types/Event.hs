{-# LANGUAGE UndecidableInstances #-}

module Crm.Types.Event (
  CustomerOnboarded (..),
  InviteCreated (..),
  InviteDeleted (..),
  CustomerStatusChanged (..),
) where

import Crm.Types.Invite (InviteId, InviteSource)
import Data.Aeson (FromJSON, ToJSON)
import Data.Time (UTCTime)
import GHC.Generics (Generic)
import Hempire.Id (CustomerId (..))
import Optics.TH (makeFieldLabelsNoPrefix)

data CustomerOnboarded = CustomerOnboarded
  { customerId :: CustomerId
  , inviteId :: InviteId
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
