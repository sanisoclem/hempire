module Hempire.Interpreter.Messaging.Kafka (runMessagingKafka) where

import Control.Exception (throwIO)
import Effectful
import Effectful.Dispatch.Dynamic
import Hempire.Effect.Messaging (Messaging (..))
import Kafka.Producer

runMessagingKafka ::
  (IOE :> es) =>
  KafkaProducer ->
  Eff (Messaging : es) a ->
  Eff es a
runMessagingKafka producer = interpret $ \_env -> \case
  SendMessage topic payload -> liftIO $ do
    err <-
      produceMessage
        producer
        ProducerRecord
          { prTopic = TopicName topic
          , prPartition = UnassignedPartition
          , prKey = Nothing
          , prValue = Just payload
          , prHeaders = mempty
          }
    mapM_ throwIO err
