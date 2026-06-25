module Crm.Core.Contact
  ( createContact
  , updateContact
    -- * Pure helpers (directly testable without effects)
  , validateCreateContact
  , validateUpdateContact
  ) where

import Crm.Core.Domain (CrmDomainError (..))
import Crm.Core.Repository (CrmRepository, contactExistsById, createContactRecord, findContactByEmail, updateContactRecord)
import Crm.Types
import Data.Aeson (toJSON)
import Data.Text (Text)
import Data.Text qualified as T
import Effectful

import Hempire.Effect.Events (Events, publishEvent)
import Hempire.Effect.Logging (Logging, logInfo)
import Hempire.Effect.Time (Time, getUtcTimestampNow)

type CrmServiceEffects es =
  ( CrmRepository :> es
  , Time          :> es
  , Events        :> es
  , Logging       :> es
  )

createContact
  :: CrmServiceEffects es
  => CreateContact
  -> Eff es (Either CrmDomainError ContactId)
createContact cmd =
  case validateCreateContact cmd of
    errs@(_:_) -> pure (Left (ContactValidationFailed errs))
    [] -> do
      existing <- findContactByEmail (ccEmail cmd)
      case existing of
        Just _ -> pure (Left (ContactEmailAlreadyExists (ccEmail cmd)))
        Nothing -> do
          now <- getUtcTimestampNow
          let contactId = ContactId (ccCorrelationId cmd)
          createContactRecord contactId (ccName cmd) (ccEmail cmd) now
          let event = ContactCreated
                { ccEvtId            = contactId
                , ccEvtName          = ccName cmd
                , ccEvtEmail         = ccEmail cmd
                , ccEvtCorrelationId = ccCorrelationId cmd
                , ccEvtAt            = now
                }
          publishEvent "crm.events" event
          logInfo "crm.contact.created" [("contactId", toJSON contactId)]
          pure (Right contactId)

updateContact
  :: CrmServiceEffects es
  => ContactId
  -> UpdateContact
  -> Eff es (Either CrmDomainError ContactId)
updateContact cid cmd =
  case validateUpdateContact cmd of
    errs@(_:_) -> pure (Left (ContactValidationFailed errs))
    [] -> do
      exists <- contactExistsById cid
      if not exists
        then pure (Left (ContactNotFound cid))
        else do
          now <- getUtcTimestampNow
          updateContactRecord cid (ucName cmd) (ucEmail cmd)
          let event = ContactUpdated
                { cuEvtId            = cid
                , cuEvtCorrelationId = ucCorrelationId cmd
                , cuEvtAt            = now
                }
          publishEvent "crm.events" event
          logInfo "crm.contact.updated" [("contactId", toJSON cid)]
          pure (Right cid)

validateCreateContact :: CreateContact -> [Text]
validateCreateContact cmd = concat
  [ ["name must not be empty"  | T.null (T.strip (ccName cmd))]
  , ["email must not be empty" | T.null (T.strip (ccEmail cmd))]
  , ["email must contain @"    | '@' `notElem` T.unpack (ccEmail cmd)]
  ]

validateUpdateContact :: UpdateContact -> [Text]
validateUpdateContact cmd = concat
  [ case ucEmail cmd of
      Just e  -> ["email must contain @" | '@' `notElem` T.unpack e]
      Nothing -> []
  ]
