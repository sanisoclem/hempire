module Main (main) where

import Test.Tasty (defaultMain, testGroup)
import Ledger.Core.EntrySpec (spec)

main :: IO ()
main = defaultMain $ testGroup "ledger-interpreters" [spec]
