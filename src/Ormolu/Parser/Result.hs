-- | A type for result of parsing.
module Ormolu.Parser.Result
  ( SourceSnippet (..),
    ParseResult (..),
  )
where

import Data.Set (Set)
import Data.Text (Text)
import Distribution.ModuleName (ModuleName)
import GHC.Data.EnumSet (EnumSet)
import GHC.Hs (GhcPs, HsModule)
import GHC.LanguageExtensions.Type
import Ormolu.Config (SourceType)
import Ormolu.Fixity (ModuleFixityMap)
import Ormolu.Parser.CommentStream
import Ormolu.Parser.Pragma (Pragma)

-- | Either a 'ParseResult', or a raw snippet.
data SourceSnippet = RawSnippet Text | ParsedSnippet ParseResult

-- | A collection of data that represents a parsed module in Ormolu.
data ParseResult = ParseResult
  { -- | Parsed module or signature
    prParsedSource :: HsModule GhcPs,
    -- | Either regular module or signature file
    prSourceType :: SourceType,
    -- | Stack header
    prStackHeader :: Maybe LComment,
    -- | Pragmas and the associated comments
    prPragmas :: [([LComment], Pragma)],
    -- | Comment stream
    prCommentStream :: CommentStream,
    -- | Enabled extensions
    prExtensions :: EnumSet Extension,
    -- | Fixity map for operators
    prModuleFixityMap :: ModuleFixityMap,
    -- | Indentation level, can be non-zero in case of region formatting
    prIndent :: Int,
    -- | Local modules
    prLocalModules :: Set ModuleName
  }
