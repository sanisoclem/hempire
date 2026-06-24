module Crm.Core.CustomerSpec (spec) where

import Crm.Types
import Data.Text (Text)
import Hempire.DomainId (DomainId (..), parseId, showId)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, testCase, (@?=))

spec :: TestTree
spec = testGroup "DomainId"
  [ testGroup "CustomerId"
    [ testCase "showId prepends prefix" $
        showId (wrapRaw "abc" :: CustomerId) @?= "cust_abc"

    , testCase "parseId strips prefix" $
        parseId "cust_abc" @?= Right (wrapRaw "abc" :: CustomerId)

    , testCase "parseId rejects wrong prefix" $
        assertBool "expected Left" $
          case (parseId "inv_abc" :: Either Text CustomerId) of
            Left _  -> True
            Right _ -> False

    , testCase "parseId rejects empty body" $
        assertBool "expected Left" $
          case (parseId "cust_" :: Either Text CustomerId) of
            Left _  -> True
            Right _ -> False

    , testCase "round-trip: showId . parseId" $
        (showId <$> (parseId "cust_abc123" :: Either Text CustomerId))
          @?= Right "cust_abc123"
    ]

  , testGroup "InviteId"
    [ testCase "showId prepends prefix" $
        showId (wrapRaw "xyz" :: InviteId) @?= "inv_xyz"

    , testCase "parseId strips prefix" $
        parseId "inv_xyz" @?= Right (wrapRaw "xyz" :: InviteId)
    ]

  , testGroup "IdentityProviderId"
    [ testCase "showId prepends prefix" $
        showId (wrapRaw "debug" :: IdentityProviderId) @?= "idp_debug"

    , testCase "parseId strips prefix" $
        parseId "idp_debug" @?= Right (wrapRaw "debug" :: IdentityProviderId)
    ]
  ]
