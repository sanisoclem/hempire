module Hempire.Interpreter.Telemetry (
  traceCorrelationFields,
  withDbSpan,
) where

import Data.Aeson (Value (..))
import Data.Text (Text)
import Data.Text qualified as T
import Hempire.Effect.Logging (LogField)
import OpenTelemetry.Context (lookupSpan)
import OpenTelemetry.Context.ThreadLocal (getContext)
import OpenTelemetry.Trace.Core (
  SpanArguments (..),
  SpanContext (..),
  SpanKind (..),
  addAttribute,
  defaultSpanArguments,
  getGlobalTracerProvider,
  getSpanContext,
  inSpan',
  isValid,
  makeTracer,
  tracerOptions,
 )
import OpenTelemetry.Trace.Id (Base (..), spanIdBaseEncodedText, traceIdBaseEncodedText)

traceCorrelationFields :: IO [LogField]
traceCorrelationFields = do
  ctx <- getContext
  case lookupSpan ctx of
    Nothing -> pure []
    Just sp -> do
      sc <- getSpanContext sp
      if isValid sc
        then
          pure
            [ ("trace_id", String (traceIdBaseEncodedText Base16 (traceId sc)))
            , ("span_id", String (spanIdBaseEncodedText Base16 (spanId sc)))
            ]
        else pure []

withDbSpan :: Text -> IO a -> IO a
withDbSpan sql action = do
  tp <- getGlobalTracerProvider
  let tracer = makeTracer tp "hempire-db" tracerOptions
      args = defaultSpanArguments {kind = Client}
  inSpan' tracer (T.take 200 sql) args $ \sp -> do
    addAttribute sp "db.system" ("postgresql" :: Text)
    action
