module Hempire.Interpreter.Time.Mock
  ( runTimeMock
  ) where

import Data.Time (UTCTime, localDay, utctDay, utcToLocalTime)
import Effectful
import Effectful.Dispatch.Dynamic

import Hempire.Effect.Time (Time (..))

runTimeMock :: UTCTime -> Eff (Time : es) a -> Eff es a
runTimeMock fixedTime = interpret $ \_env -> \case
  GetUtcTimestampNow -> pure fixedTime
  GetTodayUtc        -> pure (utctDay fixedTime)
  GetTodayIn tz      -> pure (localDay (utcToLocalTime tz fixedTime))
