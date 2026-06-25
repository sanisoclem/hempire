module Crm.Core.Domain
  ( CrmDomainError (..)
  ) where

import Crm.Types (CustomerId, InviteId)
import Data.Text (Text)

-- | Internal business-logic errors for the CRM domain.
-- Not serialised to JSON — API handlers map these to 'CrmError' at the boundary.
data CrmDomainError
  = InviteNotFound InviteId
  | InviteAlreadyClaimed InviteId
  | InviteNotActive InviteId
  | IdpNotFound Text             -- issuer URL
  | IdpNotEnabledForCustomers Text  -- issuer URL
  | CustomerNotFound CustomerId
  deriving stock (Show, Eq)
