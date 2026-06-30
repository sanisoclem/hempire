module Crm.Interpreter.Repository.Postgres (
  runCrmRepositoryPostgres,
) where

import Crm.Core.Repository (CrmRepository (..), IdpConfig (..))
import Crm.Types
import Crm.Types.IdpType (IdpType, parseIdpType)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Time (UTCTime)
import Database.PostgreSQL.Simple (Only (..))
import Effectful
import Effectful.Dispatch.Dynamic
import Effectful.Error.Static (Error, throwError)
import Hempire.DomainId (DomainId (..), parseId, showId)
import Hempire.Effect.Cache (Cache, getCachedJson, setCachedJson)
import Hempire.Effect.Database (Database, runQuery, runQuery_)
import Hempire.Effect.HempireError (HempireInternalError (..))

runCrmRepositoryPostgres ::
  (Database :> es, Cache :> es, Error HempireInternalError :> es) =>
  Eff (CrmRepository : es) a ->
  Eff es a
runCrmRepositoryPostgres = interpret $ \_env -> \case
  FindInvite iid -> do
    rows <-
      runQuery
        "SELECT invite_id, source, created_on, active, customer_id, comment \
        \FROM invites WHERE invite_id = ? LIMIT 1"
        (Only (showId iid))
    case (rows :: [(Text, Text, UTCTime, Bool, Maybe Text, Maybe Text)]) of
      (rawIid, src, ts, act, mCid, mComment) : _ -> do
        src' <- decodeSource src
        rawIid' <- parseIdOrThrow rawIid
        mCid' <- mapM parseIdOrThrow mCid
        pure $
          Just
            InviteDetails
              { inviteId = rawIid'
              , source = src'
              , createdOn = ts
              , active = act
              , customerId = mCid'
              , comment = mComment
              }
      [] -> pure Nothing
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
  CreateCustomerRecord cid ts ->
    runQuery_
      "INSERT INTO customers (customer_id, created_on, updated_on, active) \
      \VALUES (?, ?, ?, true)"
      (showId cid, ts, ts)
  CreateUserRecord cid fname identId ts ->
    runQuery_
      "INSERT INTO users (customer_id, friendly_name, identity_id, created_on) \
      \VALUES (?, ?, ?, ?)"
      (showId cid, fname, identId, ts)
  CustomerExists cid -> do
    rows <-
      runQuery
        "SELECT customer_id FROM customers WHERE customer_id = ? LIMIT 1"
        (Only (showId cid))
    pure $ not (null (rows :: [Only Text]))
  SetCustomerActive cid active ts ->
    runQuery_
      "UPDATE customers SET active = ?, updated_on = ? WHERE customer_id = ?"
      (active, ts, showId cid)
  GetIdpConfig issuer -> do
    let cacheKey = "crm:idp:" <> issuer
    mCached <- getCachedJson @IdpConfig cacheKey
    case mCached of
      Just cfg -> pure (Just cfg)
      Nothing -> do
        rows <-
          runQuery
            "SELECT enable_customers, idp_type \
            \FROM identity_providers WHERE identity_provider_id = ? LIMIT 1"
            (Only issuer)
        result <- case (rows :: [(Bool, Text)]) of
          (enabled, typ) : _ -> do
            idpTyp <- either (throwError . DecodeErr) pure (parseIdpType typ)
            pure $ Just IdpConfig{idpEnabled = enabled, idpType = idpTyp}
          [] -> pure Nothing
        mapM_ (\cfg -> setCachedJson cacheKey cfg 3600) result
        pure result

sourceToText :: InviteSource -> Text
sourceToText Referral = "referral"
sourceToText Waitlist = "waitlist"
sourceToText Debug = "debug"
sourceToText Manual = "manual"

decodeSource :: (Error HempireInternalError :> es) => Text -> Eff es InviteSource
decodeSource "referral" = pure Referral
decodeSource "waitlist" = pure Waitlist
decodeSource "debug" = pure Debug
decodeSource "manual" = pure Manual
decodeSource other = throwError (DecodeErr ("unknown invite source in DB: " <> other))

parseIdOrThrow :: (DomainId a, Error HempireInternalError :> es) => Text -> Eff es a
parseIdOrThrow t = case parseId t of
  Right x -> pure x
  Left err -> throwError (DecodeErr ("DB id parse error: " <> err))
