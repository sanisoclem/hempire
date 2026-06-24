module Hempire.Interpreter.Database.Postgres
  ( runDatabasePostgres
  , classifyException
  ) where

import Control.Exception (SomeException, fromException, try)
import Control.Monad (void)
import Data.ByteString (ByteString)
import Data.Pool (Pool, withResource)
import Data.Text qualified as T
import Data.Text.Encoding (decodeUtf8)
import Database.PostgreSQL.Simple (Connection)
import Database.PostgreSQL.Simple qualified as PG
import Effectful
import Effectful.Dispatch.Dynamic

import Hempire.Effect.Database (Database (..), DatabaseError (..))

runDatabasePostgres
  :: IOE :> es
  => Pool Connection
  -> Eff (Database : es) a
  -> Eff es (Either DatabaseError a)
runDatabasePostgres pool action =
  withEffToIO SeqUnlift $ \run ->
    fmap (either (Left . classifyException) Right) $
      try @SomeException $
        withResource pool $ \conn ->
          run $ interpret (\env -> \case
            RunQuery q args  -> liftIO $ PG.query conn q args
            RunQuery_ q args -> liftIO $ void $ PG.execute conn q args
            Execute q args   -> liftIO $ PG.execute conn q args
            WithTransaction inner ->
              localSeqUnliftIO env $ \unlift ->
                PG.withTransaction conn (unlift inner)) action

classifyException :: SomeException -> DatabaseError
classifyException ex
  | Just (e :: PG.SqlError) <- fromException ex =
      let msg = decodeUtf8 (PG.sqlErrorMsg e)
      in  if PG.sqlState e `elem` connectionStates
            then ConnectionError msg
            else QueryError msg
  | Just (e :: PG.ResultError) <- fromException ex =
      DecodeError (T.pack (show e))
  | Just (e :: PG.FormatError) <- fromException ex =
      QueryError (T.pack (show e))
  | otherwise =
      DatabaseError' (T.pack (show ex))

connectionStates :: [ByteString]
connectionStates = ["08000", "08003", "08006", "08001", "57P01"]
