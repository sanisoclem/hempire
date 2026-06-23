module Main (main) where

import Test.Tasty (defaultMain, testGroup)
import Crm.Core.ValidationSpec (spec)

main :: IO ()
main = defaultMain $ testGroup "crm-core" [spec]
