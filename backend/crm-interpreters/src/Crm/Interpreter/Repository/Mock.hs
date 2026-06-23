module Crm.Interpreter.Repository.Mock
  ( MockCrmRepository (..)
  , emptyMockCrm
  , withExistingEmail
  , withExistingContact
  , runCrmRepositoryMock
  ) where

import Crm.Core.Repository (CrmRepository (..))
import Crm.Types (ContactId (..))
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Effectful
import Effectful.Dispatch.Dynamic

data MockCrmRepository = MockCrmRepository
  { mcrExistingEmails     :: Set Text
  , mcrExistingContactIds :: Set ContactId
  }

emptyMockCrm :: MockCrmRepository
emptyMockCrm = MockCrmRepository Set.empty Set.empty

withExistingEmail :: Text -> MockCrmRepository -> MockCrmRepository
withExistingEmail email m = m { mcrExistingEmails = Set.insert email (mcrExistingEmails m) }

withExistingContact :: ContactId -> MockCrmRepository -> MockCrmRepository
withExistingContact cid m = m { mcrExistingContactIds = Set.insert cid (mcrExistingContactIds m) }

runCrmRepositoryMock :: MockCrmRepository -> Eff (CrmRepository : es) a -> Eff es a
runCrmRepositoryMock mock = interpret $ \_env -> \case
  FindContactByEmail email ->
    pure $
      if Set.member email (mcrExistingEmails mock)
        then Just (ContactId email)
        else Nothing
  ContactExistsById cid ->
    pure $ Set.member cid (mcrExistingContactIds mock)
  CreateContactRecord _ _ _ _ -> pure ()
  UpdateContactRecord _ _ _   -> pure ()
