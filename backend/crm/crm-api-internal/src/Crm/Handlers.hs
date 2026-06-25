module Crm.Handlers (
  createInviteH,
  getInviteH,
  deleteInviteH,
  deactivateCustomerH,
) where

import Crm.Auth (InternalAuth)
import Crm.Core.Customer (CrmEffect, createInvite, deactivateCustomer, deleteCustomerInvite, getCustomerInvite)
import Crm.Types
import Effectful
import Effectful.Error.Static (Error)
import Servant (ServerError)

type App es = (CrmEffect es, Error ServerError :> es)

createInviteH :: (App es) => InternalAuth -> CreateInvite -> Eff es (CrmResponse InviteId)
createInviteH _auth cmd = Ok <$> createInvite cmd

getInviteH :: (App es) => InternalAuth -> InviteId -> Eff es (CrmResponse InviteDetails)
getInviteH _auth iid = Ok <$> getCustomerInvite iid

deleteInviteH :: (App es) => InternalAuth -> InviteId -> Eff es (CrmResponse ())
deleteInviteH _auth iid = Ok <$> deleteCustomerInvite iid

deactivateCustomerH :: (App es) => InternalAuth -> CustomerId -> Eff es (CrmResponse ())
deactivateCustomerH _auth cid = Ok <$> deactivateCustomer cid
