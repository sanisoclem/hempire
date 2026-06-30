module Hempire.Env (requireEnv) where

import System.Environment (lookupEnv)

requireEnv :: String -> IO String
requireEnv k = lookupEnv k >>= maybe (fail ("required env var not set: " <> k)) pure
