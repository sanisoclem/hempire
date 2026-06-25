{-# LANGUAGE AllowAmbiguousTypes  #-}
{-# LANGUAGE ScopedTypeVariables  #-}
{-# LANGUAGE TypeApplications     #-}
-- | Prefixed domain identifiers.
--
-- Each domain ID type wraps a raw 'Text' value and carries a compile-time
-- prefix (e.g. @"cust_"@, @"inv_"@).  Serialised and stored forms always
-- include the prefix so the type of an ID can be checked at parse time.
--
-- Use 'makeDomainId' to generate a newtype plus all instances in one splice:
--
-- > makeDomainId "CustomerId" "cust_"
module Hempire.DomainId
  ( DomainId (..)
  , showId
  , parseId
  , makeDomainId
  ) where

import Data.Aeson (FromJSON (..), ToJSON (..), withText)
import Data.String (IsString (..))
import Data.Text (Text)
import Data.Text qualified as T
import Language.Haskell.TH

class DomainId a where
  idPrefix :: Text
  wrapRaw  :: Text -> a
  getRaw   :: a -> Text

-- | Produce the full serialised form: prefix <> raw.
showId :: forall a. DomainId a => a -> Text
showId a = idPrefix @a <> getRaw a

-- | Parse a prefixed string, returning the typed ID or an error message.
parseId :: forall a. DomainId a => Text -> Either Text a
parseId t = case T.stripPrefix (idPrefix @a) t of
  Nothing  -> Left ("expected prefix \"" <> idPrefix @a <> "\"")
  Just raw
    | T.null raw -> Left ("id body must not be empty after prefix \"" <> idPrefix @a <> "\"")
    | otherwise  -> Right (wrapRaw @a raw)

-- | Generate a newtype declaration and all standard instances.
--
-- @makeDomainId \"CustomerId\" \"cust_\"@ produces:
--
-- * @newtype CustomerId = CustomerId Text  deriving (Eq, Ord)@
-- * 'DomainId', 'Show', 'ToJSON', 'FromJSON', 'IsString' instances
makeDomainId :: String -> String -> Q [Dec]
makeDomainId typeName prefix = do
  let name = mkName typeName
      t    = mkName "t"
      x    = mkName "x"
      s    = mkName "s"
      e    = mkName "e"

  let newtypeDec =
        NewtypeD [] name [] Nothing
          (NormalC name [(Bang NoSourceUnpackedness NoSourceStrictness, ConT ''Text)])
          [DerivClause (Just StockStrategy) [ConT ''Eq, ConT ''Ord]]

  let domainIdInst =
        InstanceD Nothing []
          (AppT (ConT ''DomainId) (ConT name))
          [ FunD 'idPrefix [Clause [] (NormalB (AppE (VarE 'T.pack) (LitE (StringL prefix)))) []]
          , FunD 'wrapRaw  [Clause [] (NormalB (ConE name)) []]
          , FunD 'getRaw
              [Clause [ConP name [] [VarP t]] (NormalB (VarE t)) []]
          ]

  -- show cid = T.unpack (showId cid)
  let showInst =
        InstanceD Nothing []
          (AppT (ConT ''Show) (ConT name))
          [ FunD 'show
              [Clause [VarP x]
                (NormalB (AppE (VarE 'T.unpack) (AppE (VarE 'showId) (VarE x))))
                []]
          ]

  -- toJSON cid = toJSON (showId cid)  — delegates to Text instance
  let toJsonInst =
        InstanceD Nothing []
          (AppT (ConT ''ToJSON) (ConT name))
          [ FunD 'toJSON
              [Clause [VarP x]
                (NormalB (AppE (VarE 'toJSON) (AppE (VarE 'showId) (VarE x))))
                []]
          ]

  -- parseJSON = withText "TypeName" $ \s -> case parseId s of ...
  let fromJsonBody =
        AppE
          (AppE (VarE 'withText) (LitE (StringL typeName)))
          (LamE [VarP s]
            (CaseE (AppE (VarE 'parseId) (VarE s))
              [ Match (ConP 'Left  [] [VarP e]) (NormalB (AppE (VarE 'fail) (AppE (VarE 'T.unpack) (VarE e)))) []
              , Match (ConP 'Right [] [VarP x]) (NormalB (AppE (VarE 'pure) (VarE x)))                         []
              ]))
  let fromJsonInst =
        InstanceD Nothing []
          (AppT (ConT ''FromJSON) (ConT name))
          [ FunD 'parseJSON [Clause [] (NormalB fromJsonBody) []] ]

  -- fromString s = case parseId (T.pack s) of ...
  let isStringBody =
        CaseE (AppE (VarE 'parseId) (AppE (VarE 'T.pack) (VarE s)))
          [ Match (ConP 'Left  [] [VarP e]) (NormalB (AppE (VarE 'error) (AppE (VarE 'T.unpack) (VarE e)))) []
          , Match (ConP 'Right [] [VarP x]) (NormalB (VarE x))                                               []
          ]
  let isStringInst =
        InstanceD Nothing []
          (AppT (ConT ''IsString) (ConT name))
          [ FunD 'fromString [Clause [VarP s] (NormalB isStringBody) []] ]

  pure [newtypeDec, domainIdInst, showInst, toJsonInst, fromJsonInst, isStringInst]
