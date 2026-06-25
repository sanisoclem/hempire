module Main (main) where

import Hempire.DomainIdSpec (spec)
import Test.Tasty (defaultMain, testGroup)

main :: IO ()
main = defaultMain $ testGroup "hempire-public" [spec]
