module Crm.Core.Domain
  ( CrmDomainError (..)
  ) where

import Crm.Types (ContactId)
import Data.Text (Text)

-- | Business-logic errors for the CRM domain.
-- These are internal types — they are NOT serialised to JSON.
-- API handlers map them to 'CrmError' or HTTP status codes at the boundary.
data CrmDomainError
  = ContactNotFound ContactId
  | ContactEmailAlreadyExists Text
  | ContactValidationFailed [Text]
  deriving stock (Show, Eq)
