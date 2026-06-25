{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module Hempire.DomainId (
  DomainId (..),
  showId,
  parseId,
  makeDomainId,
) where

import Data.Aeson (FromJSON (..), ToJSON (..), withText)
import Data.String (IsString (..))
import Data.Text (Text)
import Data.Text qualified as T
import Language.Haskell.TH

class DomainId a where
  idPrefix :: Text
  wrapRaw :: Text -> a
  getRaw :: a -> Text

showId :: forall a. (DomainId a) => a -> Text
showId a = idPrefix @a <> getRaw a

parseId :: forall a. (DomainId a) => Text -> Either Text a
parseId t = case T.stripPrefix (idPrefix @a) t of
  Nothing -> Left ("expected prefix \"" <> idPrefix @a <> "\"")
  Just raw
    | T.null raw -> Left ("id body must not be empty after prefix \"" <> idPrefix @a <> "\"")
    | otherwise -> Right (wrapRaw @a raw)

makeDomainId :: String -> String -> Q [Dec]
makeDomainId typeName prefix = do
  let name = mkName typeName
      t = mkName "t"
      x = mkName "x"
      s = mkName "s"
      e = mkName "e"

  let newtypeDec =
        NewtypeD
          []
          name
          []
          Nothing
          (NormalC name [(Bang NoSourceUnpackedness NoSourceStrictness, ConT ''Text)])
          [DerivClause (Just StockStrategy) [ConT ''Eq, ConT ''Ord]]

  let domainIdInst =
        InstanceD
          Nothing
          []
          (AppT (ConT ''DomainId) (ConT name))
          [ FunD 'idPrefix [Clause [] (NormalB (AppE (VarE 'T.pack) (LitE (StringL prefix)))) []]
          , FunD 'wrapRaw [Clause [] (NormalB (ConE name)) []]
          , FunD
              'getRaw
              [Clause [ConP name [] [VarP t]] (NormalB (VarE t)) []]
          ]

  let showInst =
        InstanceD
          Nothing
          []
          (AppT (ConT ''Show) (ConT name))
          [ FunD
              'show
              [ Clause
                  [VarP x]
                  (NormalB (AppE (VarE 'T.unpack) (AppE (VarE 'showId) (VarE x))))
                  []
              ]
          ]

  let toJsonInst =
        InstanceD
          Nothing
          []
          (AppT (ConT ''ToJSON) (ConT name))
          [ FunD
              'toJSON
              [ Clause
                  [VarP x]
                  (NormalB (AppE (VarE 'toJSON) (AppE (VarE 'showId) (VarE x))))
                  []
              ]
          ]

  let fromJsonBody =
        AppE
          (AppE (VarE 'withText) (LitE (StringL typeName)))
          ( LamE
              [VarP s]
              ( CaseE
                  (AppE (VarE 'parseId) (VarE s))
                  [ Match (ConP 'Left [] [VarP e]) (NormalB (AppE (VarE 'fail) (AppE (VarE 'T.unpack) (VarE e)))) []
                  , Match (ConP 'Right [] [VarP x]) (NormalB (AppE (VarE 'pure) (VarE x))) []
                  ]
              )
          )
  let fromJsonInst =
        InstanceD
          Nothing
          []
          (AppT (ConT ''FromJSON) (ConT name))
          [FunD 'parseJSON [Clause [] (NormalB fromJsonBody) []]]

  let isStringBody =
        CaseE
          (AppE (VarE 'parseId) (AppE (VarE 'T.pack) (VarE s)))
          [ Match (ConP 'Left [] [VarP e]) (NormalB (AppE (VarE 'error) (AppE (VarE 'T.unpack) (VarE e)))) []
          , Match (ConP 'Right [] [VarP x]) (NormalB (VarE x)) []
          ]
  let isStringInst =
        InstanceD
          Nothing
          []
          (AppT (ConT ''IsString) (ConT name))
          [FunD 'fromString [Clause [VarP s] (NormalB isStringBody) []]]

  pure [newtypeDec, domainIdInst, showInst, toJsonInst, fromJsonInst, isStringInst]
