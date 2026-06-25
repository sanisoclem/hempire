module Crm.Handlers
  ( OnboardRequest (..)
  , onboardCustomerH
  ) where

import Crm.Auth (CustomerAuth (..))
import Crm.Core.Customer (CrmEffect, onboardCustomer)
import Crm.Core.Domain (CrmDomainError)
import Crm.Core.Idp (Idp)
import Crm.Interpreter.Error (mapCrmError)
import Crm.Types
import Data.Aeson (FromJSON, ToJSON)
import Effectful
import Effectful.Error.Static (Error, tryError)
import GHC.Generics (Generic)
import Hempire.Effect.CustomerContext (CustomerContext, getCustomerId)
import Servant (ServerError)

type App es =
  ( CrmEffect es
  , Idp :> es
  , Error ServerError :> es
  )

newtype OnboardRequest = OnboardRequest
  { inviteId :: InviteId }
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

onboardCustomerH
  :: App es
  => CustomerAuth -> OnboardRequest -> Eff es (CrmResponse CustomerId)
onboardCustomerH auth (OnboardRequest{inviteId}) = do
  mCid <- getCustomerId
  case mCid of
    Just _  -> pure (Err (Conflict "already onboarded"))
    Nothing ->
      tryError @CrmDomainError
        (onboardCustomer OnboardCustomer{identity = cauthIdentity auth, inviteId}) >>= \case
          Left (_, err) -> pure (Err (mapCrmError err))
          Right cid     -> pure (Ok cid)
