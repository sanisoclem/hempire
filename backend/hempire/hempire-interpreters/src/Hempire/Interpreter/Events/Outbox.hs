module Hempire.Interpreter.Events.Outbox
  ( runEventsOutbox
  ) where

import Data.Aeson (encode)
import Data.ByteString.Lazy qualified as BL
import Effectful
import Effectful.Dispatch.Dynamic

import Hempire.Effect.Database (Database, runQuery_)
import Hempire.Effect.Events (Events (..), TopicName (..))

-- | Outbox-pattern interpreter: writes each event as a row in the @outbox@ table.
-- Requires 'Database' in the effect stack so the write participates in the same
-- connection (and transaction) as the surrounding business logic.
runEventsOutbox :: (IOE :> es, Database :> es) => Eff (Events : es) a -> Eff es a
runEventsOutbox = interpret $ \_env -> \case
  PublishEvent (TopicName topic) payload ->
    runQuery_
      "INSERT INTO outbox (topic, payload) VALUES (?, ?::jsonb)"
      (topic, BL.toStrict (encode payload))
