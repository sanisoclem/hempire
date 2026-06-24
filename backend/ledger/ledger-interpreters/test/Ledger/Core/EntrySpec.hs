module Ledger.Core.EntrySpec (spec) where

import Ledger.Core.Entry (postEntry)
import Ledger.Core.Domain (LedgerDomainError (..))
import Ledger.Interpreter.Repository.Mock (MockLedgerRepository (..), emptyMockLedger, runLedgerRepositoryMock, withAccount)
import Ledger.Types

import Control.Concurrent.STM (newTVarIO, readTVarIO)
import Data.Time (UTCTime (..), fromGregorian, secondsToDiffTime)
import Effectful (runEff)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))

import Hempire.Interpreter.Events.Mock (runEventsMock)
import Hempire.Interpreter.Logging.Mock (runLoggingMock)
import Hempire.Interpreter.Time.Mock (runTimeMock)

spec :: TestTree
spec = testGroup "Ledger.Core.Entry"
  [ testGroup "postEntry"
    [ testCase "succeeds and publishes one event when accounts exist and funds sufficient" $ do
        eventLog <- newTVarIO []
        logLog   <- newTVarIO []
        let mock = withAccount debitId (Amount 500) $ withAccount creditId (Amount 0) emptyMockLedger
        result <- runAll mock eventLog logLog (postEntry validCmd)
        result @?= Right (EntryId "corr-1")
        events <- readTVarIO eventLog
        length events @?= 1

    , testCase "rejects when debit account does not exist" $ do
        eventLog <- newTVarIO []
        logLog   <- newTVarIO []
        let mock = withAccount creditId (Amount 0) emptyMockLedger
        result <- runAll mock eventLog logLog (postEntry validCmd)
        result @?= Left (LedgerAccountNotFound debitId)
        events <- readTVarIO eventLog
        events @?= []

    , testCase "rejects when credit account does not exist" $ do
        eventLog <- newTVarIO []
        logLog   <- newTVarIO []
        let mock = withAccount debitId (Amount 500) emptyMockLedger
        result <- runAll mock eventLog logLog (postEntry validCmd)
        result @?= Left (LedgerAccountNotFound creditId)
        events <- readTVarIO eventLog
        events @?= []

    , testCase "rejects when debit account has insufficient funds" $ do
        eventLog <- newTVarIO []
        logLog   <- newTVarIO []
        let mock = withAccount debitId (Amount 50) $ withAccount creditId (Amount 0) emptyMockLedger
        result <- runAll mock eventLog logLog (postEntry validCmd)
        result @?= Left LedgerInsufficientFunds
              { insufficientAccount = debitId
              , available           = Amount 50
              , requested           = Amount 100
              }
        events <- readTVarIO eventLog
        events @?= []
    ]
  ]
  where
    debitId  = AccountId "acc-a"
    creditId = AccountId "acc-b"

    validCmd :: PostEntry
    validCmd = PostEntry
      { peDebit         = debitId
      , peCredit        = creditId
      , peAmount        = Amount 100
      , peDescription   = "test transfer"
      , peCorrelationId = "corr-1"
      }

    fixedTime :: UTCTime
    fixedTime = UTCTime (fromGregorian 2026 6 23) (secondsToDiffTime 0)

    runAll mock eventLog logLog action =
      runEff
        $ runLoggingMock logLog
        $ runEventsMock eventLog
        $ runTimeMock fixedTime
        $ runLedgerRepositoryMock mock
        $ action
