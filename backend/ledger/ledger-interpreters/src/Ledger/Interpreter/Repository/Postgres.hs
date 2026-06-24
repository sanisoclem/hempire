module Ledger.Interpreter.Repository.Postgres
  ( runLedgerRepositoryPostgres
  ) where

import Ledger.Core.Repository (LedgerRepository (..))
import Ledger.Types (AccountId (..), Amount (..), EntryId (..))
import Data.Text (Text)
import Database.PostgreSQL.Simple (Only (..))
import Effectful
import Effectful.Dispatch.Dynamic

import Hempire.Effect.Database (Database, runQuery, runQuery_)

runLedgerRepositoryPostgres :: Database :> es => Eff (LedgerRepository : es) a -> Eff es a
runLedgerRepositoryPostgres = interpret $ \_env -> \case
  FetchAccountBalance aid -> do
    let AccountId aidText = aid
    rows <- runQuery "SELECT balance FROM accounts WHERE id = ? LIMIT 1" (Only aidText)
    pure $ case (rows :: [Only Int]) of
      (Only bal : _) -> Just (Amount bal)
      []             -> Nothing
  AccountExists aid -> do
    let AccountId aidText = aid
    rows <- runQuery "SELECT id FROM accounts WHERE id = ? LIMIT 1" (Only aidText)
    pure $ not (null (rows :: [Only Text]))
  InsertEntry eid did cid amt desc ts -> do
    let EntryId eidText   = eid
        AccountId didText = did
        AccountId cidText = cid
        Amount amtInt     = amt
    runQuery_
      "INSERT INTO ledger_entries (id, debit_account, credit_account, amount, description, created_at) VALUES (?, ?, ?, ?, ?, ?)"
      (eidText, didText, cidText, amtInt, desc, ts)
  DebitAccount aid amt -> do
    let AccountId aidText = aid
        Amount amtInt     = amt
    runQuery_
      "UPDATE accounts SET balance = balance - ? WHERE id = ?"
      (amtInt, aidText)
  CreditAccount aid amt -> do
    let AccountId aidText = aid
        Amount amtInt     = amt
    runQuery_
      "UPDATE accounts SET balance = balance + ? WHERE id = ?"
      (amtInt, aidText)
