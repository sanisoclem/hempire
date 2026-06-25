{-# LANGUAGE UndecidableInstances #-}

module Crm.Types.Command (
  OnboardCustomer (..),
  CreateInvite (..),
  DeleteCustomerInvite (..),
  DeactivateCustomer (..),
  CrmCommand (..),
) where

import Crm.Types.Invite (InviteId, InviteSource)
import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text)
import GHC.Generics (Generic)
import Hempire.Id (CustomerId (..))
import Hempire.Identity (IdentityId (..))
import Optics.TH (makeFieldLabelsNoPrefix)

data OnboardCustomer = OnboardCustomer
  { identity :: IdentityId
  , inviteId :: InviteId
  }
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

makeFieldLabelsNoPrefix ''OnboardCustomer

data CreateInvite = CreateInvite
  { source :: InviteSource
  , comment :: Maybe Text
  }
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

makeFieldLabelsNoPrefix ''CreateInvite

newtype DeleteCustomerInvite = DeleteCustomerInvite
  {inviteId :: InviteId}
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

makeFieldLabelsNoPrefix ''DeleteCustomerInvite

newtype DeactivateCustomer = DeactivateCustomer
  {customerId :: CustomerId}
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

makeFieldLabelsNoPrefix ''DeactivateCustomer

data CrmCommand
  = OnboardCustomerCommand OnboardCustomer
  | CreateInviteCommand CreateInvite
  | DeleteCustomerInviteCommand DeleteCustomerInvite
  | DeactivateCustomerCommand DeactivateCustomer
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)
