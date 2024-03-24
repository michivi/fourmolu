{-# LANGUAGE RecordWildCards #-}

import Data.Map qualified as Map
import Data.Maybe (fromMaybe, mapMaybe)
import FourmoluConfig.ConfigData
import FourmoluConfig.GenerateUtils
import Text.Printf (printf)

main :: IO ()
main = do
  writeFile "../src/Ormolu/Config/Gen.hs" configGenHs
  writeFile "../fourmolu.yaml" fourmoluYamlOrmoluStyle

configGenHs :: String
configGenHs =
  unlines
    [ "{- FOURMOLU_DISABLE -}",
      "{- ***** DO NOT EDIT: This module is autogenerated ***** -}",
      "",
      "{-# LANGUAGE DeriveGeneric #-}",
      "{-# LANGUAGE LambdaCase #-}",
      "{-# LANGUAGE OverloadedStrings #-}",
      "{-# LANGUAGE RankNTypes #-}",
      "",
      "module Ormolu.Config.Gen",
      "  ( PrinterOpts (..)",
      unlines_ $ map (printf "  , %s (..)" . fieldTypeName) allFieldTypes,
      "  , emptyPrinterOpts",
      "  , defaultPrinterOpts",
      "  , defaultPrinterOptsYaml",
      "  , fillMissingPrinterOpts",
      "  , parsePrinterOptsCLI",
      "  , parsePrinterOptsJSON",
      "  , parsePrinterOptType",
      "  )",
      "where",
      "",
      "import qualified Data.Aeson as Aeson",
      "import qualified Data.Aeson.Types as Aeson",
      "import Control.Applicative (asum)",
      "import Data.Functor.Identity (Identity)",
      "import Data.List.NonEmpty (NonEmpty)",
      "import Data.Scientific (floatingOrInteger)",
      "import qualified Data.Text as Text",
      "import GHC.Generics (Generic)",
      "import qualified Ormolu.Config.Fixed as CF",
      "import Text.Read (readEither, readMaybe)",
      "",
      "-- | Options controlling formatting output.",
      "data PrinterOpts f =",
      indent . mkPrinterOpts $ \(fieldName', Option {..}) ->
        unlines_
          [ printf "-- | %s" description,
            printf "  %s :: f %s" fieldName' type_
          ],
      "  deriving (Generic)",
      "",
      "emptyPrinterOpts :: PrinterOpts Maybe",
      "emptyPrinterOpts =",
      indent . mkPrinterOpts $ \(fieldName', _) ->
        fieldName' <> " = Nothing",
      "",
      "defaultPrinterOpts :: PrinterOpts Identity",
      "defaultPrinterOpts =",
      indent . mkPrinterOpts $ \(fieldName', Option {default_}) ->
        fieldName' <> " = pure " <> renderHs default_,
      "",
      "-- | Fill the field values that are 'Nothing' in the first argument",
      "-- with the values of the corresponding fields of the second argument.",
      "fillMissingPrinterOpts ::",
      "  forall f.",
      "  Applicative f =>",
      "  PrinterOpts Maybe ->",
      "  PrinterOpts f ->",
      "  PrinterOpts f",
      "fillMissingPrinterOpts p1 p2 =",
      indent . mkPrinterOpts $ \(fieldName', _) ->
        printf "%s = maybe (%s p2) pure (%s p1)" fieldName' fieldName' fieldName',
      "",
      "parsePrinterOptsCLI ::",
      "  Applicative f =>",
      "  (forall a. PrinterOptsFieldType a => String -> String -> String -> f (Maybe a)) ->",
      "  f (PrinterOpts Maybe)",
      "parsePrinterOptsCLI f =",
      "  pure PrinterOpts",
      indent' 2 . unlines_ $
        [ unlines_
            [ "<*> f",
              indent . unlines_ $
                [ quote name,
                  quote (getCLIHelp option),
                  quote (getCLIPlaceholder option)
                ]
            ]
        | option@Option {name, fieldName = Just _} <- allOptions
        ],
      "",
      "parsePrinterOptsJSON ::",
      "  Applicative f =>",
      "  (forall a. PrinterOptsFieldType a => String -> f (Maybe a)) ->",
      "  f (PrinterOpts Maybe)",
      "parsePrinterOptsJSON f =",
      "  pure PrinterOpts",
      indent' 2 . unlines_ $
        [ "<*> f " <> quote name
        | Option {name, fieldName = Just _} <- allOptions
        ],
      "",
      "{---------- PrinterOpts field types ----------}",
      "",
      "class Aeson.FromJSON a => PrinterOptsFieldType a where",
      "  parsePrinterOptType :: String -> Either String a",
      "",
      "instance PrinterOptsFieldType Int where",
      "  parsePrinterOptType = readEither",
      "",
      "instance PrinterOptsFieldType Bool where",
      "  parsePrinterOptType s =",
      "    case s of",
      "      \"false\" -> Right False",
      "      \"true\" -> Right True",
      "      _ ->",
      "        Left . unlines $",
      "          [ \"unknown value: \" <> show s,",
      "            \"Valid values are: \\\"false\\\" or \\\"true\\\"\"",
      "          ]",
      "",
      unlines_
        [ unlines_ $
            case fieldType of
              FieldTypeEnum {..} ->
                [ mkDataType fieldTypeName (map fst enumOptions),
                  "  deriving (Eq, Show, Enum, Bounded)",
                  ""
                ]
              FieldTypeADT {..} ->
                [ mkDataType fieldTypeName adtConstructors,
                  "  deriving (Eq, Show)",
                  ""
                ]
        | fieldType <- allFieldTypes
        ],
      unlines_
        [ unlines_ $
            case fieldType of
              FieldTypeEnum {..} ->
                [ printf "instance Aeson.FromJSON %s where" fieldTypeName,
                  printf "  parseJSON =",
                  printf "    Aeson.withText \"%s\" $ \\s ->" fieldTypeName,
                  printf "      either Aeson.parseFail pure $",
                  printf "        parsePrinterOptType (Text.unpack s)",
                  printf "",
                  printf "instance PrinterOptsFieldType %s where" fieldTypeName,
                  printf "  parsePrinterOptType s =",
                  printf "    case s of",
                  unlines_
                    [ printf "      \"%s\" -> Right %s" val con
                    | (con, val) <- enumOptions
                    ],
                  printf "      _ ->",
                  printf "        Left . unlines $",
                  printf "          [ \"unknown value: \" <> show s",
                  printf "          , \"Valid values are: %s\"" (renderEnumOptions enumOptions),
                  printf "          ]",
                  printf ""
                ]
              FieldTypeADT {..} ->
                [ printf "instance Aeson.FromJSON %s where" fieldTypeName,
                  printf "  parseJSON =",
                  indent' 2 adtParseJSON,
                  printf "",
                  printf "instance PrinterOptsFieldType %s where" fieldTypeName,
                  printf "  parsePrinterOptType =",
                  indent' 2 adtParsePrinterOptType,
                  printf ""
                ]
        | fieldType <- allFieldTypes
        ],
      "defaultPrinterOptsYaml :: String",
      "defaultPrinterOptsYaml =",
      "  unlines",
      indent' 2 (renderMultiLineStringList fourmoluYamlFourmoluStyle)
    ]
  where
    mkPrinterOpts :: ((String, Option) -> String) -> String
    mkPrinterOpts f =
      let fieldOptions = mapMaybe (\o -> (,o) <$> fieldName o) allOptions
       in unlines_
            [ "PrinterOpts",
              indent . unlines_ $
                [ printf "%c %s" delim (f option)
                | (isFirst, option) <- withFirst fieldOptions,
                  let delim = if isFirst then '{' else ','
                ],
              "  }"
            ]

    mkDataType name cons =
      unlines_ $
        "data " <> name
          : [ printf "  %c %s" delim con
            | (isFirst, con) <- withFirst cons,
              let delim = if isFirst then '=' else '|'
            ]

    renderEnumOptions enumOptions =
      renderList [printf "\\\"%s\\\"" opt | (_, opt) <- enumOptions]

    renderMultiLineStringList =
      unlines . (++ ["]"]) . zipWith (\c str -> c : ' ' : show str) ('[' : repeat ',') . lines

    getCLIHelp Option {..} =
      let help = fromMaybe description (cliHelp cliOverrides)
          choicesText =
            case type_ `Map.lookup` fieldTypesMap of
              Just FieldTypeEnum {enumOptions} ->
                printf " (choices: %s)" (renderEnumOptions enumOptions)
              _ -> ""
          defaultText =
            printf " (default: %s)" $
              fromMaybe (hs2yaml type_ default_) (cliDefault cliOverrides)
       in concat [help, choicesText, defaultText]

    getCLIPlaceholder Option {..}
      | Just placeholder <- cliPlaceholder cliOverrides = placeholder
      | "Bool" <- type_ = "BOOL"
      | "Int" <- type_ = "INT"
      | otherwise = "OPTION"

-- | Fourmolu config with ormolu-style PrinterOpts used to format source code in fourmolu repository.
fourmoluYamlOrmoluStyle :: String
fourmoluYamlOrmoluStyle = unlines $ header <> config
  where
    header =
      [ "# ----- DO NOT EDIT: This file is autogenerated ----- #",
        "",
        "# Options should imitate Ormolu's style"
      ]
    config =
      [ printf "%s: %s" name (hs2yaml type_ ormolu)
      | Option {..} <- allOptions
      ]

-- | Default fourmolu config that can be printed via `fourmolu --print-defaults`
fourmoluYamlFourmoluStyle :: String
fourmoluYamlFourmoluStyle = unlines_ config
  where
    config =
      [ printf "# %s\n%s: %s\n" (getComment opt) name (hs2yaml type_ default_)
      | opt@Option {..} <- allOptions
      ]

    getComment Option {..} =
      let help = fromMaybe description (cliHelp cliOverrides)
          choicesText =
            case type_ `Map.lookup` fieldTypesMap of
              Just FieldTypeEnum {enumOptions} ->
                printf " (choices: %s)" (renderList $ map snd enumOptions)
              _ -> ""
       in concat [help, choicesText]
