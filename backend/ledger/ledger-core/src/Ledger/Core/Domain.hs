module Ledger.Core.Domain
  ( LedgerDomainError (..)
  ) where

import Ledger.Types (AccountId, Amount)
import Data.Text (Text)

-- | Business-logic errors for the Ledger domain.
-- NOT serialised to JSON — API handlers map these to 'LedgerError' or HTTP status codes.
data LedgerDomainError
  = LedgerAccountNotFound AccountId
  | LedgerInsufficientFunds
      { insufficientAccount :: AccountId
      , available           :: Amount
      , requested           :: Amount
      }
  | LedgerEntryValidationFailed [Text]
  deriving stock (Show, Eq)
