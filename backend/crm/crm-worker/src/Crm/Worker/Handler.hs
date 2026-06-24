module Crm.Worker.Handler
  ( handleCommand
  ) where

import Crm.Core.Customer (createInvite, deactivateCustomer, deleteCustomerInvite, onboardCustomer)
import Crm.Core.CustomerContext (CustomerContext)
import Crm.Core.Idp (Idp)
import Crm.Core.Repository (CrmRepository)
import Crm.Types
import Data.Aeson (toJSON)
import Effectful
import Hempire.Effect.Events (Events)
import Hempire.Effect.IdGen (IdGen)
import Hempire.Effect.Logging (Logging, logInfo, logWarn)
import Hempire.Effect.Time (Time)

type WorkerEffects es =
  ( CrmRepository  :> es
  , CustomerContext :> es
  , Idp            :> es
  , IdGen          :> es
  , Events         :> es
  , Time           :> es
  , Logging        :> es
  )

handleCommand :: WorkerEffects es => CrmCommand -> Eff es ()
handleCommand = \case
  OnboardCustomerCommand cmd ->
    onboardCustomer cmd >>= \case
      Left err  -> logWarn "crm.command.onboard-customer.failed" [("error", toJSON (show err))]
      Right cid -> logInfo "crm.command.onboard-customer.ok"     [("customerId", toJSON cid)]
  CreateInviteCommand cmd ->
    createInvite cmd >>= \case
      Left err  -> logWarn "crm.command.create-invite.failed" [("error", toJSON (show err))]
      Right iid -> logInfo "crm.command.create-invite.ok"     [("inviteId", toJSON iid)]
  DeleteCustomerInviteCommand DeleteCustomerInvite{inviteId = iid} ->
    deleteCustomerInvite iid >>= \case
      Left err -> logWarn "crm.command.delete-invite.failed" [("error", toJSON (show err))]
      Right () -> logInfo "crm.command.delete-invite.ok"     [("inviteId", toJSON iid)]
  DeactivateCustomerCommand DeactivateCustomer{customerId = cid} ->
    deactivateCustomer cid >>= \case
      Left err -> logWarn "crm.command.deactivate-customer.failed" [("error", toJSON (show err))]
      Right () -> logInfo "crm.command.deactivate-customer.ok"     [("customerId", toJSON cid)]
