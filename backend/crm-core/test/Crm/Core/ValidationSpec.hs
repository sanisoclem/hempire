module Crm.Core.ValidationSpec (spec) where

import Crm.Core.Contact (validateCreateContact, validateUpdateContact)
import Crm.Types
import Data.Text (Text)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, testCase, (@?=))

spec :: TestTree
spec = testGroup "pure validation"
  [ testGroup "validateCreateContact"
    [ testCase "passes for valid input" $
        validateCreateContact validCmd @?= ([] :: [Text])
    , testCase "rejects blank name" $
        assertBool "expected name error" $
          not (null (validateCreateContact validCmd { ccName = "  " }))
    , testCase "rejects blank email" $
        assertBool "expected email error" $
          not (null (validateCreateContact validCmd { ccEmail = "  " }))
    , testCase "rejects email without @" $
        assertBool "expected @ error" $
          not (null (validateCreateContact validCmd { ccEmail = "notanemail" }))
    ]
  , testGroup "validateUpdateContact"
    [ testCase "passes when nothing is changed" $
        validateUpdateContact UpdateContact { ucId = ContactId "x", ucName = Nothing, ucEmail = Nothing, ucCorrelationId = "c" }
          @?= ([] :: [Text])
    , testCase "rejects email without @" $
        assertBool "expected @ error" $
          not (null (validateUpdateContact UpdateContact { ucId = ContactId "x", ucName = Nothing, ucEmail = Just "bad", ucCorrelationId = "c" }))
    ]
  ]
  where
    validCmd :: CreateContact
    validCmd = CreateContact
      { ccName          = "Alice"
      , ccEmail         = "alice@example.com"
      , ccCorrelationId = "corr-1"
      }
