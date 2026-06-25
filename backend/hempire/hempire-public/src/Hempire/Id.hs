module Hempire.Id (
  CustomerId (..),
) where

import Hempire.DomainId (makeDomainId, parseId, showId)
import Web.HttpApiData (FromHttpApiData (..), ToHttpApiData (..))

makeDomainId "CustomerId" "cust_"

instance FromHttpApiData CustomerId where parseUrlPiece = parseId
instance ToHttpApiData CustomerId where toUrlPiece = showId
