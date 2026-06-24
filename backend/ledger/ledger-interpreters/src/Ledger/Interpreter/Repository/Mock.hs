module Ledger.Interpreter.Repository.Mock
  ( MockLedgerRepository (..)
  , emptyMockLedger
  , withAccount
  , runLedgerRepositoryMock
  ) where

import Ledger.Core.Repository (LedgerRepository (..))
import Ledger.Types (AccountId, Amount)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Effectful
import Effectful.Dispatch.Dynamic

-- | Pre-configured state for the ledger repository mock.
-- Populate 'mlrAccountBalances' with accounts that "exist" and their balances.
-- Write operations (insert entry, debit, credit) are no-ops.
data MockLedgerRepository = MockLedgerRepository
  { mlrAccountBalances :: Map AccountId Amount
  }

emptyMockLedger :: MockLedgerRepository
emptyMockLedger = MockLedgerRepository Map.empty

withAccount :: AccountId -> Amount -> MockLedgerRepository -> MockLedgerRepository
withAccount aid amt m = m { mlrAccountBalances = Map.insert aid amt (mlrAccountBalances m) }

-- | Pure mock interpreter — no IO required.
runLedgerRepositoryMock :: MockLedgerRepository -> Eff (LedgerRepository : es) a -> Eff es a
runLedgerRepositoryMock mock = interpret $ \_env -> \case
  FetchAccountBalance aid ->
    pure $ Map.lookup aid (mlrAccountBalances mock)
  AccountExists aid ->
    pure $ Map.member aid (mlrAccountBalances mock)
  InsertEntry _ _ _ _ _ _ -> pure ()
  DebitAccount  _ _       -> pure ()
  CreditAccount _ _       -> pure ()
