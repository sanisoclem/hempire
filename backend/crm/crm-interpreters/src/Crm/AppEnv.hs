module Crm.AppEnv (newCrmAppEnv) where

import Data.ByteString.Char8 qualified as BS8
import Hempire.AppEnv (AppEnv, newAppEnv)
import Hempire.Env (requireEnv)

newCrmAppEnv :: IO AppEnv
newCrmAppEnv = do
  connStr <- requireEnv "CRM_DATABASE_URL"
  newAppEnv (BS8.pack connStr)
