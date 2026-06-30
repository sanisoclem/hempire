{-# LANGUAGE QuasiQuotes #-}

module Hempire.Interpreter.Telemetry (
  traceCorrelationFields,
  withDbSpan,
  withRequestId,
) where

import Control.Exception (finally)
import Data.Aeson (Value (..))
import Data.Text (Text)
import Data.Text qualified as T
import Hempire.Effect.Logging (LogField)
import OpenTelemetry.Baggage qualified as Baggage
import OpenTelemetry.Context (insertBaggage, lookupBaggage, lookupSpan)
import OpenTelemetry.Context.ThreadLocal (attachContext, detachContext, getContext)
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

withRequestId :: Text -> IO a -> IO a
withRequestId rid action = do
  let bag = Baggage.insert [Baggage.token|request-id|] (Baggage.element rid) Baggage.empty
  ctx <- getContext
  tok <- attachContext (insertBaggage bag ctx)
  action `finally` detachContext tok

traceCorrelationFields :: IO [LogField]
traceCorrelationFields = do
  ctx <- getContext
  let ridFields = case lookupBaggage ctx >>= Baggage.getValue [Baggage.token|request-id|] of
        Just rid -> [("request_id", String rid)]
        Nothing -> []
  traceFields <- case lookupSpan ctx of
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
  pure (ridFields ++ traceFields)

withDbSpan :: Text -> IO a -> IO a
withDbSpan sql action = do
  tp <- getGlobalTracerProvider
  let tracer = makeTracer tp "hempire-db" tracerOptions
      args = defaultSpanArguments {kind = Client}
  inSpan' tracer (T.take 200 sql) args $ \sp -> do
    addAttribute sp "db.system" ("postgresql" :: Text)
    addAttribute sp "db.statement" (T.take 1000 sql)
    action
