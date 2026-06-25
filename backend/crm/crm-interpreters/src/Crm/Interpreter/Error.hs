module Crm.Interpreter.Error
  ( mapCrmError
  ) where

import Crm.Core.Domain (CrmDomainError)
import Crm.Core.Domain qualified as Domain
import Crm.Types (CrmError (..))

mapCrmError :: CrmDomainError -> CrmError
mapCrmError = \case
  Domain.InviteNotFound _            -> NotFound "invite"
  Domain.InviteAlreadyClaimed _      -> Conflict "invite already claimed"
  Domain.InviteNotActive _           -> Conflict "invite not active"
  Domain.IdpNotFound _               -> Conflict "idp not configured"
  Domain.IdpNotEnabledForCustomers _ -> Conflict "idp not enabled for customers"
  Domain.CustomerNotFound _          -> NotFound "customer"
