module Main (main) where

import Crm.Core.CustomerSpec (spec)
import Test.Tasty (defaultMain, testGroup)

main :: IO ()
main = defaultMain $ testGroup "crm-core" [spec]
