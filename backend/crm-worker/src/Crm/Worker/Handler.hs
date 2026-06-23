module Crm.Worker.Handler
  ( handleCommand
  ) where

import Crm.Core.Contact (createContact, updateContact)
import Crm.Core.Repository (CrmRepository)
import Crm.Types
import Data.Aeson (toJSON)
import Effectful
import Hempire.Effect.Events (Events)
import Hempire.Effect.Logging (Logging, logInfo, logWarn)
import Hempire.Effect.Time (Time)

type WorkerEffects es =
  ( CrmRepository :> es
  , Events        :> es
  , Time          :> es
  , Logging       :> es
  )

handleCommand :: WorkerEffects es => CrmCommand -> Eff es ()
handleCommand = \case
  CreateContactCommand cmd ->
    createContact cmd >>= \case
      Left err ->
        logWarn "crm.command.create-contact.failed"
          [("error", toJSON (show err)), ("email", toJSON (ccEmail cmd))]
      Right cid ->
        logInfo "crm.command.create-contact.ok"
          [("contactId", toJSON cid)]
  UpdateContactCommand cmd ->
    updateContact (ucId cmd) cmd >>= \case
      Left err ->
        logWarn "crm.command.update-contact.failed"
          [("error", toJSON (show err)), ("contactId", toJSON (ucId cmd))]
      Right cid ->
        logInfo "crm.command.update-contact.ok"
          [("contactId", toJSON cid)]
