module Crm.Interpreter.Repository.Postgres
  ( runCrmRepositoryPostgres
  ) where

import Crm.Core.Repository (CrmRepository (..))
import Crm.Types (ContactId (..))
import Data.Text (Text)
import Database.PostgreSQL.Simple (Only (..))
import Effectful
import Effectful.Dispatch.Dynamic

import Hempire.Effect.Database (Database, runQuery, runQuery_)

runCrmRepositoryPostgres :: Database :> es => Eff (CrmRepository : es) a -> Eff es a
runCrmRepositoryPostgres = interpret $ \_env -> \case
  FindContactByEmail email -> do
    rows <- runQuery "SELECT id FROM contacts WHERE email = ? LIMIT 1" (Only email)
    pure $ case (rows :: [Only Text]) of
      (Only cid : _) -> Just (ContactId cid)
      []             -> Nothing
  ContactExistsById cid -> do
    let ContactId cidText = cid
    rows <- runQuery "SELECT id FROM contacts WHERE id = ? LIMIT 1" (Only cidText)
    pure $ not (null (rows :: [Only Text]))
  CreateContactRecord contactId name email ts -> do
    let ContactId cidText = contactId
    runQuery_
      "INSERT INTO contacts (id, name, email, created_at) VALUES (?, ?, ?, ?)"
      (cidText, name, email, ts)
  UpdateContactRecord cid mName mEmail -> do
    let ContactId cidText = cid
    runQuery_
      "UPDATE contacts SET name = COALESCE(?, name), email = COALESCE(?, email) WHERE id = ?"
      (mName, mEmail, cidText)
