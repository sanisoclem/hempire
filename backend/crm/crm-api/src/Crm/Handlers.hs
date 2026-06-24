module Crm.Handlers
  ( onboardCustomerH
  , createInviteH
  , getInviteH
  , deleteInviteH
  , deactivateCustomerH
  ) where

import Crm.Auth (CrmAuthResult (..))
import Crm.Core.Customer
import Crm.Core.Domain (CrmDomainError (..))
import Crm.Types hiding (InviteAlreadyClaimed)
import Effectful
import Effectful.Error.Static (Error, throwError)
import Servant (ServerError, err403)

type App es =
  ( CrmEffect es
  , Error ServerError :> es
  )

onboardCustomerH
  :: App es
  => CrmAuthResult -> OnboardCustomer -> Eff es (CrmResponse CustomerId)
onboardCustomerH auth cmd = do
  requireBff auth
  case auth of
    BffAuth{authCustomerId = Just _} ->
      pure (Err (Conflict "already onboarded"))
    _ ->
      mapCrmError <$> onboardCustomer cmd

createInviteH
  :: App es
  => CrmAuthResult -> CreateInvite -> Eff es (CrmResponse InviteId)
createInviteH auth cmd = do
  requireInternal auth
  mapCrmError <$> createInvite cmd

getInviteH
  :: App es
  => InviteId -> CrmAuthResult -> Eff es (CrmResponse InviteDetails)
getInviteH iid auth = do
  requireInternal auth
  mapCrmError <$> getCustomerInvite iid

deleteInviteH
  :: App es
  => InviteId -> CrmAuthResult -> Eff es (CrmResponse ())
deleteInviteH iid auth = do
  requireInternal auth
  mapCrmError <$> deleteCustomerInvite iid

deactivateCustomerH
  :: App es
  => CustomerId -> CrmAuthResult -> Eff es (CrmResponse ())
deactivateCustomerH cid auth = do
  requireInternal auth
  mapCrmError <$> deactivateCustomer cid

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

requireBff :: Error ServerError :> es => CrmAuthResult -> Eff es ()
requireBff BffAuth{} = pure ()
requireBff InternalAuth = throwError err403

requireInternal :: Error ServerError :> es => CrmAuthResult -> Eff es ()
requireInternal InternalAuth = pure ()
requireInternal BffAuth{}   = throwError err403

mapCrmError :: Either CrmDomainError a -> CrmResponse a
mapCrmError (Right a) = Ok a
mapCrmError (Left e)  = Err $ case e of
  InviteNotFound _            -> NotFound "invite"
  InviteAlreadyClaimed _      -> Conflict "invite already claimed"
  InviteNotActive _           -> Conflict "invite not active"
  IdpNotFound _               -> Conflict "idp not configured"
  IdpNotEnabledForCustomers _ -> Conflict "idp not enabled for customers"
  CustomerNotFound _          -> NotFound "customer"
