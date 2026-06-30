module Hempire.Interpreter.Messaging.Kafka (runMessagingKafka) where

import Control.Exception (throwIO)
import Data.ByteString (ByteString)
import Data.Text.Encoding (encodeUtf8)
import Effectful
import Effectful.Dispatch.Dynamic
import Hempire.Effect.Messaging (Messaging (..))
import Kafka.Producer
import OpenTelemetry.Context (lookupSpan)
import OpenTelemetry.Context.ThreadLocal (getContext)
import OpenTelemetry.Trace.Core (SpanContext (..), getSpanContext, isValid)
import OpenTelemetry.Trace.Id (Base (..), spanIdBaseEncodedText, traceIdBaseEncodedText)

runMessagingKafka ::
  (IOE :> es) =>
  KafkaProducer ->
  Eff (Messaging : es) a ->
  Eff es a
runMessagingKafka producer = interpret $ \_env -> \case
  SendMessage topic payload -> liftIO $ do
    headers <- traceHeaders
    err <-
      produceMessage
        producer
        ProducerRecord
          { prTopic = TopicName topic
          , prPartition = UnassignedPartition
          , prKey = Nothing
          , prValue = Just payload
          , prHeaders = headersFromList headers
          }
    mapM_ throwIO err

traceHeaders :: IO [(ByteString, ByteString)]
traceHeaders = do
  ctx <- getContext
  case lookupSpan ctx of
    Nothing -> pure []
    Just sp -> do
      sc <- getSpanContext sp
      if isValid sc
        then pure [("traceparent", traceparentBytes sc)]
        else pure []

traceparentBytes :: SpanContext -> ByteString
traceparentBytes sc =
  "00-"
    <> encodeUtf8 (traceIdBaseEncodedText Base16 (traceId sc))
    <> "-"
    <> encodeUtf8 (spanIdBaseEncodedText Base16 (spanId sc))
    <> "-01"
