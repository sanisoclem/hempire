module Hempire.Interpreter.Database.Postgres (
  runDatabasePostgres,
  classifyException,
) where

import Control.Exception (SomeException, fromException, onException, try)
import Control.Monad (void)
import Data.ByteString (ByteString)
import Data.Pool (Pool, withResource)
import Data.Text qualified as T
import Data.Text.Encoding (decodeUtf8)
import Database.PostgreSQL.Simple (Connection)
import Database.PostgreSQL.Simple qualified as PG
import Database.PostgreSQL.Simple.Types (fromQuery)
import Effectful
import Effectful.Dispatch.Dynamic
import Effectful.Error.Static (Error, throwError)
import Hempire.Effect.Database (Database (..), DatabaseError (..))
import Hempire.Effect.HempireError (HempireInternalError (..))
import Hempire.Interpreter.Telemetry (withDbSpan)

runDatabasePostgres ::
  (IOE :> es, Error HempireInternalError :> es) =>
  Pool Connection ->
  Eff (Database : es) a ->
  Eff es a
runDatabasePostgres pool action = do
  result <-
    withEffToIO SeqUnlift $ \run ->
      fmap (either (Left . classifyException) Right) $
        try @SomeException $
          withResource pool $ \conn ->
            run $
              interpret
                ( \env -> \case
                    RunQuery q args -> liftIO $ withDbSpan (decodeUtf8 (fromQuery q)) $ PG.query conn q args
                    RunQuery_ q args -> liftIO $ withDbSpan (decodeUtf8 (fromQuery q)) $ void $ PG.execute conn q args
                    Execute q args -> liftIO $ withDbSpan (decodeUtf8 (fromQuery q)) $ PG.execute conn q args
                    WithTransaction inner ->
                      localSeqUnliftIO env $ \unlift ->
                        PG.withTransaction conn (unlift inner)
                    WithTransactionRollback inner ->
                      localSeqUnliftIO env $ \unlift -> do
                        PG.begin conn
                        r <- unlift inner `onException` PG.rollback conn
                        case r of
                          Left _ -> PG.rollback conn >> pure r
                          Right _ -> PG.commit conn >> pure r
                )
                action
  case result of
    Left dbErr -> throwError (DatabaseErr dbErr)
    Right a -> pure a

classifyException :: SomeException -> DatabaseError
classifyException ex
  | Just (e :: PG.SqlError) <- fromException ex =
      let msg = decodeUtf8 (PG.sqlErrorMsg e)
       in if PG.sqlState e `elem` connectionStates
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
