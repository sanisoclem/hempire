module Hempire.Effect.IdGen (
  IdGen (..),
  newId,
  deriveId,
) where

import Data.Text (Text)
import Effectful
import Effectful.TH (makeEffect)
import Hempire.DomainId (DomainId (..))

data IdGen :: Effect where
  NewIdRaw :: IdGen m Text
  DeriveIdRaw :: Text -> IdGen m Text

type instance DispatchOf IdGen = Dynamic

makeEffect ''IdGen

newId :: (IdGen :> es, DomainId a) => Eff es a
newId = wrapRaw <$> newIdRaw

deriveId :: (IdGen :> es, DomainId a, DomainId b) => a -> Eff es b
deriveId src = wrapRaw <$> deriveIdRaw (getRaw src)
