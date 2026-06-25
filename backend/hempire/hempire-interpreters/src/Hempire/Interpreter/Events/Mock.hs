module Hempire.Interpreter.Events.Mock (
  runEventsMock,
) where

import Control.Concurrent.STM (TVar, atomically, modifyTVar)
import Data.Aeson (encode)
import Data.ByteString (ByteString)
import Data.ByteString.Lazy qualified as BL
import Effectful
import Effectful.Dispatch.Dynamic
import Hempire.Effect.Events (Events (..), TopicName)

runEventsMock ::
  (IOE :> es) =>
  TVar [(TopicName, ByteString)] ->
  Eff (Events : es) a ->
  Eff es a
runEventsMock captured = interpret $ \_env -> \case
  PublishEvent topic payload ->
    liftIO $
      atomically $
        modifyTVar captured (++ [(topic, BL.toStrict (encode payload))])
