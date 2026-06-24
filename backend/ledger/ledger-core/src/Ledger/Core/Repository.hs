module Ledger.Core.Repository
  ( -- * Effect
    LedgerRepository (..)
    -- * Operations
  , fetchAccountBalance
  , accountExists
  , insertEntry
  , debitAccount
  , creditAccount
  ) where

import Ledger.Types (AccountId, Amount, EntryId)
import Data.Text (Text)
import Data.Time (UTCTime)
import Effectful
import Effectful.Dispatch.Dynamic
import Effectful.TH (makeEffect)

data LedgerRepository :: Effect where
  FetchAccountBalance :: AccountId -> LedgerRepository m (Maybe Amount)
  AccountExists       :: AccountId -> LedgerRepository m Bool
  InsertEntry         :: EntryId -> AccountId -> AccountId -> Amount -> Text -> UTCTime -> LedgerRepository m ()
  DebitAccount        :: AccountId -> Amount -> LedgerRepository m ()
  CreditAccount       :: AccountId -> Amount -> LedgerRepository m ()

type instance DispatchOf LedgerRepository = Dynamic

makeEffect ''LedgerRepository
