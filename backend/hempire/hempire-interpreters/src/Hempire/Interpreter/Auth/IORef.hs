module Hempire.Interpreter.Auth.IORef
  ( runAuthIORef
  ) where

import Data.IORef (IORef, readIORef)
import Data.Set qualified as Set
import Effectful
import Effectful.Dispatch.Dynamic
import Hempire.Effect.Auth (Auth (..), AuthError (..), Principal (..))

runAuthIORef :: IOE :> es => IORef (Maybe Principal) -> Eff (Auth : es) a -> Eff es a
runAuthIORef ref = interpret $ \_env -> \case
  GetCurrentPrincipal -> liftIO $ readIORef ref
  RequirePermission perm -> liftIO $ do
    mp <- readIORef ref
    pure $ case mp of
      Nothing -> Left Unauthenticated
      Just p  ->
        if perm `Set.member` principalPermissions p
          then Right p
          else Left (Forbidden perm)
