module Crm.Handlers (
  OnboardRequest (..),
  onboardCustomerH,
) where

import Crm.Auth (CustomerAuth (..))
import Crm.Core.Customer (CrmEffect, onboardCustomer)
import Crm.Core.Idp (Idp)
import Crm.Types
import Data.Aeson (FromJSON, ToJSON)
import Effectful
import Effectful.Error.Static (Error)
import GHC.Generics (Generic)
import Hempire.Effect.CustomerContext (getCustomerId)
import Servant (ServerError)

type App es =
  ( CrmEffect es
  , Idp :> es
  , Error ServerError :> es
  )

newtype OnboardRequest = OnboardRequest
  {inviteId :: InviteId}
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

onboardCustomerH ::
  (App es) =>
  CustomerAuth -> OnboardRequest -> Eff es (CrmResponse OnboardResponse)
onboardCustomerH auth (OnboardRequest {inviteId}) = do
  mCid <- getCustomerId
  case mCid of
    Just _ -> pure (Err (Conflict "already onboarded"))
    Nothing -> Ok <$> onboardCustomer OnboardCustomer {identity = cauthIdentity auth, inviteId}
