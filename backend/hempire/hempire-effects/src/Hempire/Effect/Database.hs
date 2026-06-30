module Hempire.Effect.Database (
  Database (..),
  runQuery,
  runQuery_,
  execute,
  withTransaction,
  withTransactionRollback,
  DatabaseError (..),
) where

import Data.Int (Int64)
import Data.Text (Text)
import Database.PostgreSQL.Simple (FromRow, Query, ToRow)
import Effectful
import Effectful.TH (makeEffect)

data DatabaseError
  = ConnectionError Text
  | QueryError Text
  | DecodeError Text
  | NotFound
  | TooManyRows
  | DatabaseError' Text
  deriving stock (Show, Eq)

data Database :: Effect where
  RunQuery :: (FromRow r, ToRow q) => Query -> q -> Database m [r]
  RunQuery_ :: (ToRow q) => Query -> q -> Database m ()
  Execute :: (ToRow q) => Query -> q -> Database m Int64
  WithTransaction :: m a -> Database m a
  WithTransactionRollback :: m (Either e a) -> Database m (Either e a)

type instance DispatchOf Database = Dynamic

makeEffect ''Database
