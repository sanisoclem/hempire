module Main (main) where

import Test.Tasty (defaultMain, testGroup)
import Crm.Core.ContactSpec (spec)

main :: IO ()
main = defaultMain $ testGroup "crm-interpreters" [spec]
