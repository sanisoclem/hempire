module Crm.Core.Repository
  ( -- * Effect
    CrmRepository (..)
    -- * Operations
  , findContactByEmail
  , contactExistsById
  , createContactRecord
  , updateContactRecord
  ) where

import Crm.Types (ContactId)
import Data.Text (Text)
import Data.Time (UTCTime)
import Effectful
import Effectful.Dispatch.Dynamic
import Effectful.TH (makeEffect)

data CrmRepository :: Effect where
  FindContactByEmail  :: Text      -> CrmRepository m (Maybe ContactId)
  ContactExistsById   :: ContactId -> CrmRepository m Bool
  CreateContactRecord :: ContactId -> Text -> Text -> UTCTime -> CrmRepository m ()
  UpdateContactRecord :: ContactId -> Maybe Text -> Maybe Text -> CrmRepository m ()

type instance DispatchOf CrmRepository = Dynamic

makeEffect ''CrmRepository
