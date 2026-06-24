module Ledger.Handlers
  ( postEntryH
  ) where

import Ledger.Core qualified as Core
import Ledger.Core.Domain
import Ledger.Core.Repository (LedgerRepository)
import Ledger.Types
import Effectful
import Effectful.Error.Static (Error, throwError)
import Servant (ServerError, err401, err403)

import Hempire.Effect.Auth (Auth, AuthError (..), Permission (..), requirePermission)
import Hempire.Effect.Events (Events)
import Hempire.Effect.Logging (Logging)
import Hempire.Effect.Time (Time)

type HandlerEffects es =
  ( LedgerRepository :> es
  , Time             :> es
  , Events           :> es
  , Auth             :> es
  , Logging          :> es
  , Error ServerError :> es
  )

postEntryH
  :: HandlerEffects es
  => PostEntry
  -> Eff es (LedgerResponse EntryId)
postEntryH cmd = do
  checkPermission "ledger:write"
  Core.postEntry cmd >>= \case
    Left (LedgerEntryValidationFailed errs) ->
      pure (Err (ValidationFailed errs))
    Left (LedgerAccountNotFound aid) ->
      pure (Err (AccountNotFound aid))
    Left (LedgerInsufficientFunds { insufficientAccount, available }) ->
      pure (Err (InsufficientFunds insufficientAccount available))
    Right entryId ->
      pure (Ok entryId)

checkPermission :: HandlerEffects es => Permission -> Eff es ()
checkPermission perm =
  requirePermission perm >>= \case
    Left Unauthenticated -> throwError err401
    Left (Forbidden _)   -> throwError err403
    Right _              -> pure ()
