module Ledger.Core.ValidationSpec (spec) where

import Ledger.Core.Entry (validatePostEntry)
import Ledger.Types
import Data.Text (Text)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, testCase, (@?=))

spec :: TestTree
spec = testGroup "pure validation"
  [ testGroup "validatePostEntry"
    [ testCase "passes for valid input" $
        validatePostEntry validCmd @?= ([] :: [Text])
    , testCase "rejects zero amount" $
        assertBool "expected amount error" $
          not (null (validatePostEntry validCmd { peAmount = Amount 0 }))
    , testCase "rejects negative amount" $
        assertBool "expected amount error" $
          not (null (validatePostEntry validCmd { peAmount = Amount (-1) }))
    , testCase "rejects same debit and credit account" $
        assertBool "expected same-account error" $
          not (null (validatePostEntry validCmd { peCredit = AccountId "acc-a" }))
    ]
  ]
  where
    validCmd :: PostEntry
    validCmd = PostEntry
      { peDebit         = AccountId "acc-a"
      , peCredit        = AccountId "acc-b"
      , peAmount        = Amount 100
      , peDescription   = "test transfer"
      , peCorrelationId = "corr-1"
      }
