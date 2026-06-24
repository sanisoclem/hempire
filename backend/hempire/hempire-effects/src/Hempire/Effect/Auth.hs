module Hempire.Effect.Auth
  ( -- * Effect
    Auth (..)
    -- * Operations
  , getCurrentPrincipal
  , requirePermission
    -- * Types
  , Principal (..)
  , Permission (..)
  , AuthError (..)
  ) where

import Data.Set (Set)
import Data.String (IsString)
import Data.Text (Text)
import Effectful
import Effectful.Dispatch.Dynamic
import Effectful.TH (makeEffect)

data Principal = Principal
  { principalId          :: Text
  , principalPermissions :: Set Permission
  }
  deriving stock (Show, Eq)

newtype Permission = Permission Text
  deriving stock (Show, Eq, Ord)
  deriving newtype (IsString)

data AuthError
  = Unauthenticated
  | Forbidden Permission
  deriving stock (Show, Eq)

data Auth :: Effect where
  GetCurrentPrincipal :: Auth m (Maybe Principal)
  RequirePermission   :: Permission -> Auth m (Either AuthError Principal)

type instance DispatchOf Auth = Dynamic

makeEffect ''Auth
