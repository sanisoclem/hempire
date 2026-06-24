module Main (main) where

import Test.Tasty (defaultMain, testGroup)
import Ledger.Core.ValidationSpec (spec)

main :: IO ()
main = defaultMain $ testGroup "ledger-core" [spec]
