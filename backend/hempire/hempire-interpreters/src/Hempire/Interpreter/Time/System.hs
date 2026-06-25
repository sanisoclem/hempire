module Hempire.Interpreter.Time.System (
  runTimeSystem,
) where

import Data.Time (getCurrentTime, utcToLocalTime, utctDay)
import Data.Time qualified as Time
import Effectful
import Effectful.Dispatch.Dynamic
import Hempire.Effect.Time (Time (..))

runTimeSystem :: (IOE :> es) => Eff (Time : es) a -> Eff es a
runTimeSystem = interpret $ \_env -> \case
  GetUtcTimestampNow -> liftIO getCurrentTime
  GetTodayUtc -> liftIO $ utctDay <$> getCurrentTime
  GetTodayIn tz -> liftIO $ Time.localDay . utcToLocalTime tz <$> getCurrentTime
