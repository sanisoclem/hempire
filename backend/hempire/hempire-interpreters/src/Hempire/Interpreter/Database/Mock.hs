module Hempire.Interpreter.Database.Mock
  ( MockDbState
  , newMockDbState
  , queueResponse
  , getQueryLog
  , runDatabaseMock
  ) where

import Data.IORef (IORef, modifyIORef, newIORef, readIORef, writeIORef)
import Data.Text (Text)
import Effectful
import Effectful.Dispatch.Dynamic
import Unsafe.Coerce (unsafeCoerce)

import Hempire.Effect.Database (Database (..), DatabaseError (..))

data StoredRows = forall a. StoredRows [a]

data MockDbState = MockDbState
  { mockResponses :: IORef [StoredRows]
  , mockQueryLog  :: IORef [Text]
  }

newMockDbState :: IO MockDbState
newMockDbState = MockDbState <$> newIORef [] <*> newIORef []

queueResponse :: [a] -> MockDbState -> IO ()
queueResponse rows st = modifyIORef (mockResponses st) (++ [StoredRows rows])

getQueryLog :: MockDbState -> IO [Text]
getQueryLog = readIORef . mockQueryLog

runDatabaseMock
  :: IOE :> es
  => MockDbState
  -> Eff (Database : es) a
  -> Eff es (Either DatabaseError a)
runDatabaseMock st = fmap Right . interpret (\env -> \case
  RunQuery _ _  -> liftIO (popResponse st)
  RunQuery_ _ _ -> pure ()
  Execute _ _   -> pure 0
  WithTransaction inner -> localSeqUnlift env $ \unlift -> unlift inner)

popResponse :: MockDbState -> IO [r]
popResponse st = do
  queue <- readIORef (mockResponses st)
  case queue of
    []                       -> pure []
    (StoredRows rows : rest) -> do
      writeIORef (mockResponses st) rest
      pure (unsafeCoerce rows)
