module Crm.Core.CustomerSpec (spec) where

import Crm.Core.Customer
import Crm.Core.Domain (CrmDomainError (..))
import Crm.Interpreter.CustomerContext (runInternalContext)
import Crm.Interpreter.Repository.Mock
import Crm.Types hiding (InviteAlreadyClaimed)

import Control.Concurrent.STM (newTVarIO, readTVarIO)
import Data.Time (UTCTime (..), fromGregorian, secondsToDiffTime)
import Effectful (runEff)
import Hempire.DomainId (DomainId (..))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))

import Hempire.Interpreter.Events.Mock (runEventsMock)
import Hempire.Interpreter.IdGen.Mock (runIdGenMock)
import Hempire.Interpreter.Logging.Mock (runLoggingMock)
import Hempire.Interpreter.Time.Mock (runTimeMock)

fixedTime :: UTCTime
fixedTime = UTCTime (fromGregorian 2026 6 24) (secondsToDiffTime 0)

-- The mock DeriveId returns "derived_" <> input, so
-- onboardCustomer with invite "inv_testinviteid" produces:
--   deriveId "testinviteid" = "derived_testinviteid"
--   wrapRaw "derived_testinviteid" :: CustomerId
expectedCid :: CustomerId
expectedCid = wrapRaw "derived_testinviteid"

testInviteId :: InviteId
testInviteId = wrapRaw "testinviteid"

testIdpId :: IdentityProviderId
testIdpId = wrapRaw "debug"

testIdentity :: Identity
testIdentity = Identity{providerId = testIdpId, identityId = "user-001"}

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
claimedInvite = activeInvite { Crm.Types.customerId = Just expectedCid }

inactiveInvite :: InviteDetails
inactiveInvite = activeInvite { active = False }

spec :: TestTree
spec = testGroup "Crm.Core.Customer"
  [ testGroup "onboardCustomer"
    [ testCase "success: returns CustomerId and publishes event" $ do
        eventLog <- newTVarIO []
        logLog   <- newTVarIO []
        let mock = withIdpEnabled testIdpId
                 . withInvite activeInvite
                 $ emptyMockCrm
            cmd  = OnboardCustomer{identity = testIdentity, inviteId = testInviteId}
        result <- runAll "testinviteid" mock eventLog logLog (onboardCustomer cmd)
        result @?= Right expectedCid
        events <- readTVarIO eventLog
        length events @?= 1

    , testCase "rejects disabled IdP" $ do
        eventLog <- newTVarIO []
        logLog   <- newTVarIO []
        let mock = withInvite activeInvite emptyMockCrm  -- IdP not enabled
            cmd  = OnboardCustomer{identity = testIdentity, inviteId = testInviteId}
        result <- runAll "testinviteid" mock eventLog logLog (onboardCustomer cmd)
        result @?= Left (IdpNotEnabledForCustomers testIdpId)
        events <- readTVarIO eventLog
        events @?= []

    , testCase "rejects missing invite" $ do
        eventLog <- newTVarIO []
        logLog   <- newTVarIO []
        let mock = withIdpEnabled testIdpId emptyMockCrm  -- no invite
            cmd  = OnboardCustomer{identity = testIdentity, inviteId = testInviteId}
        result <- runAll "testinviteid" mock eventLog logLog (onboardCustomer cmd)
        result @?= Left (InviteNotFound testInviteId)

    , testCase "rejects inactive invite" $ do
        eventLog <- newTVarIO []
        logLog   <- newTVarIO []
        let mock = withIdpEnabled testIdpId
                 . withInvite inactiveInvite
                 $ emptyMockCrm
            cmd  = OnboardCustomer{identity = testIdentity, inviteId = testInviteId}
        result <- runAll "testinviteid" mock eventLog logLog (onboardCustomer cmd)
        result @?= Left (InviteNotActive testInviteId)

    , testCase "rejects already claimed invite" $ do
        eventLog <- newTVarIO []
        logLog   <- newTVarIO []
        let mock = withIdpEnabled testIdpId
                 . withInvite claimedInvite
                 $ emptyMockCrm
            cmd  = OnboardCustomer{identity = testIdentity, inviteId = testInviteId}
        result <- runAll "testinviteid" mock eventLog logLog (onboardCustomer cmd)
        result @?= Left (InviteAlreadyClaimed testInviteId)
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
        events <- readTVarIO eventLog
        events @?= []

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

  , testGroup "getOnboardingStatus"
    [ testCase "not onboarded" $ do
        eventLog <- newTVarIO []
        logLog   <- newTVarIO []
        result <- runAll "x" emptyMockCrm eventLog logLog
          (getOnboardingStatus testIdentity)
        result @?= NotOnboarded

    , testCase "onboarded" $ do
        eventLog <- newTVarIO []
        logLog   <- newTVarIO []
        let mock = withIdentity testIdpId "user-001" expectedCid emptyMockCrm
        result <- runAll "x" mock eventLog logLog
          (getOnboardingStatus testIdentity)
        result @?= Onboarded expectedCid
    ]

  , testGroup "deactivateCustomer"
    [ testCase "success: publishes CustomerDeactivated" $ do
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
        events <- readTVarIO eventLog
        events @?= []
    ]
  ]
  where
    runAll newIdVal mock eventLog logLog action =
      runEff
        $ runLoggingMock logLog
        $ runEventsMock eventLog
        $ runTimeMock fixedTime
        $ runIdGenMock newIdVal
        $ runInternalContext
        $ runCrmRepositoryMock mock
        $ action
