module Hempire.Effect.Time
  ( -- * Effect
    Time (..)
    -- * Operations
  , getUtcTimestampNow
  , getTodayUtc
  , getTodayIn
  ) where

import Data.Time (Day, TimeZone, UTCTime)
import Effectful
import Effectful.Dispatch.Dynamic
import Effectful.TH (makeEffect)

data Time :: Effect where
  GetUtcTimestampNow :: Time m UTCTime
  GetTodayUtc        :: Time m Day
  GetTodayIn         :: TimeZone -> Time m Day

type instance DispatchOf Time = Dynamic

makeEffect ''Time
