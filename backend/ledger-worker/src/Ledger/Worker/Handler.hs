module Ledger.Worker.Handler
  ( handleCommand
  ) where

import Ledger.Core.Entry (postEntry)
import Ledger.Core.Repository (LedgerRepository)
import Ledger.Types
import Data.Aeson (toJSON)
import Effectful
import Hempire.Effect.Events (Events)
import Hempire.Effect.Logging (Logging, logInfo, logWarn)
import Hempire.Effect.Time (Time)

type WorkerEffects es =
  ( LedgerRepository :> es
  , Events           :> es
  , Time             :> es
  , Logging          :> es
  )

handleCommand :: WorkerEffects es => LedgerCommand -> Eff es ()
handleCommand = \case
  PostEntryCommand cmd ->
    postEntry cmd >>= \case
      Left err ->
        logWarn "ledger.command.post-entry.failed"
          [("error", toJSON (show err)), ("correlationId", toJSON (peCorrelationId cmd))]
      Right entryId ->
        logInfo "ledger.command.post-entry.ok"
          [("entryId", toJSON entryId)]
