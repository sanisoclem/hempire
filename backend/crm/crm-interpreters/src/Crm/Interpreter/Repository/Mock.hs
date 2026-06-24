module Crm.Interpreter.Repository.Mock
  ( MockCrmRepository (..)
  , emptyMockCrm
  , withIdpConfig
  , withInvite
  , withCustomer
  , runCrmRepositoryMock
  ) where

import Crm.Core.Repository (CrmRepository (..), IdpConfig (..))
import Crm.Types
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Effectful
import Effectful.Dispatch.Dynamic
import Optics.Core

data MockCrmRepository = MockCrmRepository
  { invites     :: Map InviteId InviteDetails
  , customers   :: Set CustomerId
  , idpConfigs  :: Map IdentityProviderId IdpConfig
  }

emptyMockCrm :: MockCrmRepository
emptyMockCrm = MockCrmRepository Map.empty Set.empty Map.empty

withIdpConfig :: IdentityProviderId -> IdpConfig -> MockCrmRepository -> MockCrmRepository
withIdpConfig idpId cfg m = m { idpConfigs = Map.insert idpId cfg (idpConfigs m) }

withInvite :: InviteDetails -> MockCrmRepository -> MockCrmRepository
withInvite inv m = m { invites = Map.insert (inv ^. #inviteId) inv (invites m) }

withCustomer :: CustomerId -> MockCrmRepository -> MockCrmRepository
withCustomer cid m = m { customers = Set.insert cid (customers m) }

runCrmRepositoryMock :: MockCrmRepository -> Eff (CrmRepository : es) a -> Eff es a
runCrmRepositoryMock mock = interpret $ \_env -> \case
  FindInvite iid ->
    pure $ Map.lookup iid (invites mock)

  CreateInviteRecord _ _ _ _ ->
    pure ()

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

  GetIdpConfig idpId ->
    pure $ Map.lookup idpId (idpConfigs mock)
