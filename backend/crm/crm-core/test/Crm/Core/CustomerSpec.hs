module Crm.Core.CustomerSpec (spec) where

import Crm.Core.Customer
import Crm.Core.Domain (CrmDomainError (..))
import Crm.Core.Repository (IdpConfig (..))
import Crm.Interpreter.Idp.Mock (runIdpMock)
import Crm.Interpreter.Repository.Mock
import Crm.Types hiding (InviteAlreadyClaimed)

import Control.Concurrent.STM (newTVarIO, readTVarIO)
import Data.Text (Text)
import Data.Time (UTCTime (..), fromGregorian, secondsToDiffTime)
import Effectful (runEff)
import Effectful.Error.Static (runError)
import Hempire.DomainId (DomainId (..))
import Hempire.Identity (IdentityId (..))
import Hempire.Interpreter.CustomerContext (runInternalContext)
import Hempire.Interpreter.Events.Mock (runEventsMock)
import Hempire.Interpreter.IdGen.Mock (runIdGenMock)
import Hempire.Interpreter.Logging.Mock (runLoggingMock)
import Hempire.Interpreter.Time.Mock (runTimeMock)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))

fixedTime :: UTCTime
fixedTime = UTCTime (fromGregorian 2026 6 24) (secondsToDiffTime 0)

expectedCid :: CustomerId
expectedCid = wrapRaw "derived_testinviteid"

testInviteId :: InviteId
testInviteId = wrapRaw "testinviteid"

testIssuer :: Text
testIssuer = "http://localhost:8081"

testIdentity :: IdentityId
testIdentity = IdentityId{identityIssuer = testIssuer, identitySub = "user-001"}

testIdpConfig :: IdpConfig
testIdpConfig = IdpConfig{idpEnabled = True, idpType = "zitadel"}

activeInvite :: InviteDetails
activeInvite = InviteDetails
  { inviteId   = testInviteId
  , source     = Debug
  , createdOn  = fixedTime
  , active     = True
  , customerId = Nothing
  , comment    = Nothing
  }

claimedInvite :: InviteDetails
claimedInvite = activeInvite{customerId = Just expectedCid}

inactiveInvite :: InviteDetails
inactiveInvite = activeInvite{active = False}

spec :: TestTree
spec = testGroup "Crm.Core.Customer"
  [ testGroup "onboardCustomer"
    [ testCase "success: returns CustomerId and publishes event" $ do
        eventLog <- newTVarIO []
        logLog   <- newTVarIO []
        let mock = withIdpConfig testIssuer testIdpConfig
                 . withInvite activeInvite
                 $ emptyMockCrm
        result <- runAll "testinviteid" mock eventLog logLog
          (onboardCustomer OnboardCustomer{identity = testIdentity, inviteId = testInviteId})
        result @?= Right expectedCid
        events <- readTVarIO eventLog
        length events @?= 1

    , testCase "idempotent: succeeds if customer already exists, no new event" $ do
        eventLog <- newTVarIO []
        logLog   <- newTVarIO []
        let mock = withIdpConfig testIssuer testIdpConfig
                 . withInvite claimedInvite
                 . withCustomer expectedCid
                 $ emptyMockCrm
        result <- runAll "testinviteid" mock eventLog logLog
          (onboardCustomer OnboardCustomer{identity = testIdentity, inviteId = testInviteId})
        result @?= Right expectedCid
        events <- readTVarIO eventLog
        events @?= []

    , testCase "rejects missing IdP" $ do
        eventLog <- newTVarIO []
        logLog   <- newTVarIO []
        let mock = withInvite activeInvite emptyMockCrm
        result <- runAll "testinviteid" mock eventLog logLog
          (onboardCustomer OnboardCustomer{identity = testIdentity, inviteId = testInviteId})
        result @?= Left (IdpNotFound testIssuer)

    , testCase "rejects disabled IdP" $ do
        eventLog <- newTVarIO []
        logLog   <- newTVarIO []
        let mock = withIdpConfig testIssuer testIdpConfig{idpEnabled = False}
                 . withInvite activeInvite
                 $ emptyMockCrm
        result <- runAll "testinviteid" mock eventLog logLog
          (onboardCustomer OnboardCustomer{identity = testIdentity, inviteId = testInviteId})
        result @?= Left (IdpNotEnabledForCustomers testIssuer)

    , testCase "rejects missing invite" $ do
        eventLog <- newTVarIO []
        logLog   <- newTVarIO []
        let mock = withIdpConfig testIssuer testIdpConfig emptyMockCrm
        result <- runAll "testinviteid" mock eventLog logLog
          (onboardCustomer OnboardCustomer{identity = testIdentity, inviteId = testInviteId})
        result @?= Left (InviteNotFound testInviteId)

    , testCase "rejects inactive invite" $ do
        eventLog <- newTVarIO []
        logLog   <- newTVarIO []
        let mock = withIdpConfig testIssuer testIdpConfig
                 . withInvite inactiveInvite
                 $ emptyMockCrm
        result <- runAll "testinviteid" mock eventLog logLog
          (onboardCustomer OnboardCustomer{identity = testIdentity, inviteId = testInviteId})
        result @?= Left (InviteNotActive testInviteId)
    ]

  , testGroup "createInvite"
    [ testCase "returns InviteId and publishes InviteCreated" $ do
        eventLog <- newTVarIO []
        logLog   <- newTVarIO []
        result <- runAll "newinviteid" emptyMockCrm eventLog logLog
          (createInvite CreateInvite{source = Debug, comment = Nothing})
        result @?= Right (wrapRaw "newinviteid")
        events <- readTVarIO eventLog
        length events @?= 1
    ]

  , testGroup "deleteCustomerInvite"
    [ testCase "success: deletes unclaimed invite and publishes event" $ do
        eventLog <- newTVarIO []
        logLog   <- newTVarIO []
        let mock = withInvite activeInvite emptyMockCrm
        result <- runAll "x" mock eventLog logLog (deleteCustomerInvite testInviteId)
        result @?= Right ()
        events <- readTVarIO eventLog
        length events @?= 1

    , testCase "rejects claimed invite" $ do
        eventLog <- newTVarIO []
        logLog   <- newTVarIO []
        let mock = withInvite claimedInvite emptyMockCrm
        result <- runAll "x" mock eventLog logLog (deleteCustomerInvite testInviteId)
        result @?= Left (InviteAlreadyClaimed testInviteId)

    , testCase "rejects missing invite" $ do
        eventLog <- newTVarIO []
        logLog   <- newTVarIO []
        result <- runAll "x" emptyMockCrm eventLog logLog (deleteCustomerInvite testInviteId)
        result @?= Left (InviteNotFound testInviteId)
    ]

  , testGroup "getCustomerInvite"
    [ testCase "found" $ do
        eventLog <- newTVarIO []
        logLog   <- newTVarIO []
        let mock = withInvite activeInvite emptyMockCrm
        result <- runAll "x" mock eventLog logLog (getCustomerInvite testInviteId)
        result @?= Right activeInvite

    , testCase "not found" $ do
        eventLog <- newTVarIO []
        logLog   <- newTVarIO []
        result <- runAll "x" emptyMockCrm eventLog logLog (getCustomerInvite testInviteId)
        result @?= Left (InviteNotFound testInviteId)
    ]

  , testGroup "deactivateCustomer"
    [ testCase "success: publishes CustomerStatusChanged" $ do
        eventLog <- newTVarIO []
        logLog   <- newTVarIO []
        let mock = withCustomer expectedCid emptyMockCrm
        result <- runAll "x" mock eventLog logLog (deactivateCustomer expectedCid)
        result @?= Right ()
        events <- readTVarIO eventLog
        length events @?= 1

    , testCase "rejects missing customer" $ do
        eventLog <- newTVarIO []
        logLog   <- newTVarIO []
        result <- runAll "x" emptyMockCrm eventLog logLog (deactivateCustomer expectedCid)
        result @?= Left (CustomerNotFound expectedCid)
    ]
  ]
  where
    runAll newIdVal mock eventLog logLog action = do
      outcome <- runEff
        $ runLoggingMock logLog
        $ runEventsMock eventLog
        $ runTimeMock fixedTime
        $ runIdGenMock newIdVal
        $ runInternalContext
        $ runIdpMock
        $ runCrmRepositoryMock mock
        $ runError @CrmDomainError action
      pure $ case outcome of
        Left (_, err) -> Left err
        Right a       -> Right a
