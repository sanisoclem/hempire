module Crm.Core.ContactSpec (spec) where

import Crm.Core.Contact (createContact, updateContact)
import Crm.Core.Domain (CrmDomainError (..))
import Crm.Interpreter.Repository.Mock (MockCrmRepository (..), emptyMockCrm, runCrmRepositoryMock, withExistingContact, withExistingEmail)
import Crm.Types

import Control.Concurrent.STM (newTVarIO, readTVarIO)
import Data.Time (UTCTime (..), fromGregorian, secondsToDiffTime)
import Effectful (runEff)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertFailure, testCase, (@?=))

import Hempire.Interpreter.Events.Mock (runEventsMock)
import Hempire.Interpreter.Logging.Mock (runLoggingMock)
import Hempire.Interpreter.Time.Mock (runTimeMock)

spec :: TestTree
spec = testGroup "Crm.Core.Contact"
  [ testGroup "createContact"
    [ testCase "returns Ok and publishes one event on success" $ do
        eventLog <- newTVarIO []
        logLog   <- newTVarIO []
        result <- runAll emptyMockCrm eventLog logLog (createContact validCmd)
        result @?= Right (ContactId "corr-1")
        events <- readTVarIO eventLog
        length events @?= 1

    , testCase "rejects duplicate email without publishing event" $ do
        eventLog <- newTVarIO []
        logLog   <- newTVarIO []
        let mock = withExistingEmail "alice@example.com" emptyMockCrm
        result <- runAll mock eventLog logLog (createContact validCmd)
        result @?= Left (ContactEmailAlreadyExists "alice@example.com")
        events <- readTVarIO eventLog
        events @?= []

    , testCase "rejects invalid input before touching repo" $ do
        eventLog <- newTVarIO []
        logLog   <- newTVarIO []
        result <- runAll emptyMockCrm eventLog logLog
          (createContact validCmd { ccEmail = "notanemail" })
        case result of
          Left (ContactValidationFailed _) -> pure ()
          other -> assertFailure ("expected ContactValidationFailed, got: " ++ show other)
        events <- readTVarIO eventLog
        events @?= []
    ]

  , testGroup "updateContact"
    [ testCase "returns Ok and publishes one event when contact exists" $ do
        eventLog <- newTVarIO []
        logLog   <- newTVarIO []
        let cid  = ContactId "corr-1"
            mock = withExistingContact cid emptyMockCrm
        result <- runAll mock eventLog logLog
          (updateContact cid UpdateContact { ucId = cid, ucName = Just "Bob", ucEmail = Nothing, ucCorrelationId = "upd-1" })
        result @?= Right cid
        events <- readTVarIO eventLog
        length events @?= 1

    , testCase "returns ContactNotFound when contact is missing" $ do
        eventLog <- newTVarIO []
        logLog   <- newTVarIO []
        let cid  = ContactId "missing"
        result <- runAll emptyMockCrm eventLog logLog
          (updateContact cid UpdateContact { ucId = cid, ucName = Just "Bob", ucEmail = Nothing, ucCorrelationId = "upd-2" })
        result @?= Left (ContactNotFound cid)
        events <- readTVarIO eventLog
        events @?= []
    ]
  ]
  where
    validCmd :: CreateContact
    validCmd = CreateContact
      { ccName          = "Alice"
      , ccEmail         = "alice@example.com"
      , ccCorrelationId = "corr-1"
      }

    fixedTime :: UTCTime
    fixedTime = UTCTime (fromGregorian 2026 6 23) (secondsToDiffTime 0)

    runAll mock eventLog logLog action =
      runEff
        $ runLoggingMock logLog
        $ runEventsMock eventLog
        $ runTimeMock fixedTime
        $ runCrmRepositoryMock mock
        $ action
