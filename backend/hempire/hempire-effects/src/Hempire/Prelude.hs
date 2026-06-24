-- | Convenient re-exports for effectful primitives used across all services.
module Hempire.Prelude
  ( -- * Core effect monad
    Eff
  , (:>)
  , IOE
  , runEff
  , liftIO
  , withEffToIO
  , UnliftStrategy (..)
    -- * Error effect
  , Error
  , throwError
  , catchError
  , runError
  ) where

import Effectful (Eff, IOE, UnliftStrategy (..), liftIO, runEff, withEffToIO, type (:>))
import Effectful.Error.Static (Error, catchError, runError, throwError)
