{-# LANGUAGE UndecidableInstances #-}
module Crm.Types.Invite
  ( InviteId (..)
  , InviteSource (..)
  , InviteDetails (..)
  ) where

import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text)
import Data.Time (UTCTime)
import GHC.Generics (Generic)
import Hempire.DomainId (makeDomainId, parseId, showId)
import Hempire.Id (CustomerId (..))
import Optics.TH (makeFieldLabelsNoPrefix)
import Web.HttpApiData (FromHttpApiData (..), ToHttpApiData (..))

makeDomainId "InviteId" "inv_"

instance FromHttpApiData InviteId where parseUrlPiece = parseId
instance ToHttpApiData   InviteId where toUrlPiece    = showId

data InviteSource
  = Referral
  | Waitlist
  | Debug
  | Manual
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data InviteDetails = InviteDetails
  { inviteId   :: InviteId
  , source     :: InviteSource
  , createdOn  :: UTCTime
  , active     :: Bool
  , customerId :: Maybe CustomerId
  , comment    :: Maybe Text
  }
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

makeFieldLabelsNoPrefix ''InviteDetails
