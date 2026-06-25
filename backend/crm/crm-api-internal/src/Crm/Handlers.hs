module Crm.Handlers
  ( createInviteH
  , getInviteH
  , deleteInviteH
  , deactivateCustomerH
  ) where

import Crm.Auth (InternalAuth)
import Crm.Core.Customer (CrmEffect, createInvite, deleteCustomerInvite, deactivateCustomer, getCustomerInvite)
import Crm.Core.Domain (CrmDomainError)
import Crm.Interpreter.Error (mapCrmError)
import Crm.Types
import Effectful
import Effectful.Error.Static (Error, tryError)
import Servant (ServerError)

type App es = (CrmEffect es, Error ServerError :> es)

withCrmError :: (Error CrmDomainError :> es) => Eff es a -> Eff es (CrmResponse a)
withCrmError action = tryError @CrmDomainError action >>= \case
  Left (_, err) -> pure (Err (mapCrmError err))
  Right a       -> pure (Ok a)

createInviteH   :: App es => InternalAuth -> CreateInvite -> Eff es (CrmResponse InviteId)
createInviteH _auth cmd = withCrmError (createInvite cmd)

getInviteH      :: App es => InternalAuth -> InviteId -> Eff es (CrmResponse InviteDetails)
getInviteH _auth iid = withCrmError (getCustomerInvite iid)

deleteInviteH   :: App es => InternalAuth -> InviteId -> Eff es (CrmResponse ())
deleteInviteH _auth iid = withCrmError (deleteCustomerInvite iid)

deactivateCustomerH :: App es => InternalAuth -> CustomerId -> Eff es (CrmResponse ())
deactivateCustomerH _auth cid = withCrmError (deactivateCustomer cid)
