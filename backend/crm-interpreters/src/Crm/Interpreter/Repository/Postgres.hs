module Crm.Interpreter.Repository.Postgres
  ( runCrmRepositoryPostgres
  ) where

import Crm.Core.Repository (CrmRepository (..))
import Crm.Types
import Data.Text (Text)
import Data.Text qualified as T
import Data.Time (UTCTime)
import Database.PostgreSQL.Simple (Only (..))
import Effectful
import Effectful.Dispatch.Dynamic
import Hempire.DomainId (DomainId (..), parseId, showId)
import Hempire.Effect.Database (Database, runQuery, runQuery_)

runCrmRepositoryPostgres :: Database :> es => Eff (CrmRepository : es) a -> Eff es a
runCrmRepositoryPostgres = interpret $ \_env -> \case
  -- Invite ------------------------------------------------------------------
  FindInvite iid -> do
    rows <- runQuery
      "SELECT invite_id, source, created_on, active, customer_id, comment \
      \FROM invites WHERE invite_id = ? LIMIT 1"
      (Only (showId iid))
    pure $ case (rows :: [(Text, Text, UTCTime, Bool, Maybe Text, Maybe Text)]) of
      (rawIid, src, ts, act, mCid, mComment) : _ ->
        Just InviteDetails
          { inviteId   = unsafeParseId rawIid
          , source     = textToSource src
          , createdOn  = ts
          , active     = act
          , customerId = fmap unsafeParseId mCid
          , comment    = mComment
          }
      [] -> Nothing

  CreateInviteRecord iid src ts mComment ->
    runQuery_
      "INSERT INTO invites (invite_id, source, created_on, active, comment) \
      \VALUES (?, ?, ?, true, ?)"
      (showId iid, sourceToText src, ts, mComment)

  ClaimInvite iid cid ->
    runQuery_
      "UPDATE invites SET customer_id = ? WHERE invite_id = ?"
      (showId cid, showId iid)

  DeleteInviteRecord iid ->
    runQuery_
      "DELETE FROM invites WHERE invite_id = ?"
      (Only (showId iid))

  -- Customer ----------------------------------------------------------------
  CreateCustomerRecord cid ts ->
    runQuery_
      "INSERT INTO customers (customer_id, created_on, updated_on, active) \
      \VALUES (?, ?, ?, true)"
      (showId cid, ts, ts)

  CustomerExists cid -> do
    rows <- runQuery
      "SELECT customer_id FROM customers WHERE customer_id = ? LIMIT 1"
      (Only (showId cid))
    pure $ not (null (rows :: [Only Text]))

  SetCustomerActive cid active ts ->
    runQuery_
      "UPDATE customers SET active = ?, updated_on = ? WHERE customer_id = ?"
      (active, ts, showId cid)

  -- Identity ----------------------------------------------------------------
  FindCustomerByIdentity idpId identId -> do
    rows <- runQuery
      "SELECT customer_id FROM identities \
      \WHERE identity_provider_id = ? AND identity_id = ? LIMIT 1"
      (showId idpId, identId)
    pure $ case (rows :: [Only Text]) of
      Only rawCid : _ -> Just (unsafeParseId rawCid)
      []              -> Nothing

  CreateIdentityRecord idpId identId cid ->
    runQuery_
      "INSERT INTO identities (identity_provider_id, identity_id, customer_id, active) \
      \VALUES (?, ?, ?, true)"
      (showId idpId, identId, showId cid)

  -- IdP ---------------------------------------------------------------------
  IsIdpEnabledForCustomers idpId -> do
    rows <- runQuery
      "SELECT enable_customers FROM identity_providers \
      \WHERE identity_provider_id = ? LIMIT 1"
      (Only (showId idpId))
    pure $ case (rows :: [Only Bool]) of
      Only flag : _ -> flag
      []            -> False

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

sourceToText :: InviteSource -> Text
sourceToText Referral = "referral"
sourceToText Waitlist = "waitlist"
sourceToText Debug    = "debug"
sourceToText Manual   = "manual"

textToSource :: Text -> InviteSource
textToSource "referral" = Referral
textToSource "waitlist" = Waitlist
textToSource "debug"    = Debug
textToSource "manual"   = Manual
textToSource other      = error ("unknown invite source in DB: " <> T.unpack other)

unsafeParseId :: DomainId a => Text -> a
unsafeParseId t = case parseId t of
  Right x  -> x
  Left err -> error ("DB id parse error: " <> T.unpack err)
