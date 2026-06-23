module Hempire.Interpreter.Auth.Mock
  ( runAuthMock
  ) where

import Data.Set qualified as Set
import Effectful
import Effectful.Dispatch.Dynamic

import Hempire.Effect.Auth (Auth (..), AuthError (..), Principal (..))

runAuthMock :: Maybe Principal -> Eff (Auth : es) a -> Eff es a
runAuthMock mp = interpret $ \_env -> \case
  GetCurrentPrincipal -> pure mp
  RequirePermission perm -> pure $ case mp of
    Nothing -> Left Unauthenticated
    Just p  ->
      if perm `Set.member` principalPermissions p
        then Right p
        else Left (Forbidden perm)
