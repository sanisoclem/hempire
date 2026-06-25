module Crm.Interpreter.Error (
  mapCrmError,
) where

import Crm.Core.Domain (CrmDomainError)
import Crm.Core.Domain qualified as Domain
import Crm.Types (CrmError (..))

mapCrmError :: CrmDomainError -> Maybe CrmError
mapCrmError = \case
  Domain.InviteNotFound _ -> Just (NotFound "invite")
  Domain.InviteAlreadyClaimed _ -> Just (Conflict "invite already claimed")
  Domain.InviteNotActive _ -> Just (Conflict "invite not active")
  Domain.IdpNotFound _ -> Just (Conflict "idp not configured")
  Domain.IdpNotEnabledForCustomers _ -> Just (Conflict "idp not enabled for customers")
  Domain.CustomerNotFound _ -> Just (NotFound "customer")
