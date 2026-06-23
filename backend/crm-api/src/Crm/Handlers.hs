module Crm.Handlers
  ( createContactH
  , updateContactH
  ) where

import Crm.Core qualified as Core
import Crm.Core.Domain
import Crm.Core.Repository (CrmRepository)
import Crm.Types
import Data.Text (Text)
import Effectful
import Effectful.Error.Static (Error, throwError)
import Servant (ServerError, err401, err403, err404)

import Hempire.Effect.Auth (Auth, AuthError (..), Permission (..), requirePermission)
import Hempire.Effect.Events (Events)
import Hempire.Effect.Logging (Logging)
import Hempire.Effect.Time (Time)

type HandlerEffects es =
  ( CrmRepository :> es
  , Time          :> es
  , Events        :> es
  , Auth          :> es
  , Logging       :> es
  , Error ServerError :> es
  )

createContactH
  :: HandlerEffects es
  => CreateContact
  -> Eff es (CrmResponse ContactId)
createContactH cmd = do
  checkPermission "contacts:write"
  Core.createContact cmd >>= \case
    Left (ContactValidationFailed errs) -> pure (Err (ValidationFailed errs))
    Left (ContactEmailAlreadyExists e)  -> pure (Err (Conflict e))
    Left (ContactNotFound _)            -> throwError err404
    Right contactId                     -> pure (Ok contactId)

updateContactH
  :: HandlerEffects es
  => Text
  -> UpdateContact
  -> Eff es (CrmResponse ContactId)
updateContactH rawId cmd = do
  checkPermission "contacts:write"
  let cid = ContactId rawId
  Core.updateContact cid cmd >>= \case
    Left (ContactValidationFailed errs) -> pure (Err (ValidationFailed errs))
    Left (ContactNotFound _)            -> pure (Err (NotFound rawId))
    Left (ContactEmailAlreadyExists e)  -> pure (Err (Conflict e))
    Right contactId                     -> pure (Ok contactId)

checkPermission :: HandlerEffects es => Permission -> Eff es ()
checkPermission perm =
  requirePermission perm >>= \case
    Left Unauthenticated -> throwError err401
    Left (Forbidden _)   -> throwError err403
    Right _              -> pure ()
