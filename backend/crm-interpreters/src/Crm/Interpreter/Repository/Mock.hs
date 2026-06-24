module Crm.Interpreter.Repository.Mock
  ( MockCrmRepository (..)
  , emptyMockCrm
  , withIdpEnabled
  , withInvite
  , withCustomer
  , withIdentity
  , runCrmRepositoryMock
  ) where

import Crm.Core.Repository (CrmRepository (..))
import Crm.Types
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Effectful
import Effectful.Dispatch.Dynamic
import Optics.Core

data MockCrmRepository = MockCrmRepository
  { invites    :: Map InviteId InviteDetails
  , customers  :: Set CustomerId
  , identities :: Map (IdentityProviderId, Text) CustomerId
  , idpFlags   :: Map IdentityProviderId Bool
  }

emptyMockCrm :: MockCrmRepository
emptyMockCrm = MockCrmRepository Map.empty Set.empty Map.empty Map.empty

withIdpEnabled :: IdentityProviderId -> MockCrmRepository -> MockCrmRepository
withIdpEnabled idpId m = m { idpFlags = Map.insert idpId True (idpFlags m) }

withInvite :: InviteDetails -> MockCrmRepository -> MockCrmRepository
withInvite inv m = m { invites = Map.insert (inv ^. #inviteId) inv (invites m) }

withCustomer :: CustomerId -> MockCrmRepository -> MockCrmRepository
withCustomer cid m = m { customers = Set.insert cid (customers m) }

withIdentity :: IdentityProviderId -> Text -> CustomerId -> MockCrmRepository -> MockCrmRepository
withIdentity idpId identId cid m =
  m { identities = Map.insert (idpId, identId) cid (identities m) }

runCrmRepositoryMock :: MockCrmRepository -> Eff (CrmRepository : es) a -> Eff es a
runCrmRepositoryMock mock = interpret $ \_env -> \case
  FindInvite iid ->
    pure $ Map.lookup iid (invites mock)

  CreateInviteRecord _ _ _ _ ->
    pure ()  -- no-op in mock; tests seed via withInvite

  ClaimInvite _ _ ->
    pure ()

  DeleteInviteRecord _ ->
    pure ()

  CreateCustomerRecord _ _ ->
    pure ()

  CustomerExists cid ->
    pure $ Set.member cid (customers mock)

  SetCustomerActive _ _ _ ->
    pure ()

  FindCustomerByIdentity idpId identId ->
    pure $ Map.lookup (idpId, identId) (identities mock)

  CreateIdentityRecord _ _ _ ->
    pure ()

  IsIdpEnabledForCustomers idpId ->
    pure $ Map.findWithDefault False idpId (idpFlags mock)
