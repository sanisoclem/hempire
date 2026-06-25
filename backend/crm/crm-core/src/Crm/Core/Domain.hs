module Crm.Core.Domain (
  CrmDomainError (..),
) where

import Crm.Types (CustomerId, InviteId)
import Data.Text (Text)

data CrmDomainError
  = InviteNotFound InviteId
  | InviteAlreadyClaimed InviteId
  | InviteNotActive InviteId
  | IdpNotFound Text
  | IdpNotEnabledForCustomers Text
  | CustomerNotFound CustomerId
  deriving stock (Show, Eq)
