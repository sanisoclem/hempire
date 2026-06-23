module Ledger.Core.Entry
  ( postEntry
    -- * Pure helpers
  , validatePostEntry
  ) where

import Ledger.Core.Domain (LedgerDomainError (..))
import Ledger.Core.Repository (LedgerRepository, accountExists, creditAccount, debitAccount, fetchAccountBalance, insertEntry)
import Ledger.Types
import Data.Aeson (toJSON)
import Data.Text (Text)
import Effectful

import Hempire.Effect.Events (Events, publishEvent)
import Hempire.Effect.Logging (Logging, logInfo)
import Hempire.Effect.Time (Time, getUtcTimestampNow)

type CoreEffects es =
  ( LedgerRepository :> es
  , Time             :> es
  , Events           :> es
  , Logging          :> es
  )

postEntry
  :: CoreEffects es
  => PostEntry
  -> Eff es (Either LedgerDomainError EntryId)
postEntry cmd =
  case validatePostEntry cmd of
    errs@(_:_) -> pure (Left (LedgerEntryValidationFailed errs))
    [] -> do
      mBalance <- fetchAccountBalance (peDebit cmd)
      case mBalance of
        Nothing -> pure (Left (LedgerAccountNotFound (peDebit cmd)))
        Just balance -> do
          creditOk <- accountExists (peCredit cmd)
          if not creditOk
            then pure (Left (LedgerAccountNotFound (peCredit cmd)))
            else
              let Amount requestedAmt = peAmount cmd
                  Amount availableAmt = balance
              in if availableAmt < requestedAmt
                  then pure $ Left LedgerInsufficientFunds
                        { insufficientAccount = peDebit cmd
                        , available           = balance
                        , requested           = peAmount cmd
                        }
                  else do
                    now <- getUtcTimestampNow
                    let entryId = EntryId (peCorrelationId cmd)
                    insertEntry entryId (peDebit cmd) (peCredit cmd) (peAmount cmd) (peDescription cmd) now
                    debitAccount  (peDebit cmd)  (peAmount cmd)
                    creditAccount (peCredit cmd) (peAmount cmd)
                    let event = EntryPosted
                          { epEvtId            = entryId
                          , epEvtDebit         = peDebit cmd
                          , epEvtCredit        = peCredit cmd
                          , epEvtAmount        = peAmount cmd
                          , epEvtCorrelationId = peCorrelationId cmd
                          , epEvtAt            = now
                          }
                    publishEvent "ledger.events" event
                    logInfo "ledger.entry.posted" [("entryId", toJSON entryId)]
                    pure (Right entryId)

validatePostEntry :: PostEntry -> [Text]
validatePostEntry cmd = concat
  [ ["amount must be positive"               | unAmount (peAmount cmd) <= 0]
  , ["debit and credit accounts must differ" | peDebit cmd == peCredit cmd]
  ]
