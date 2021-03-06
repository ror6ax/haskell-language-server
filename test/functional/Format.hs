{-# LANGUAGE OverloadedStrings #-}
module Format (tests) where

import Control.Monad.IO.Class
import Data.Aeson
import qualified Data.Text as T
import Language.Haskell.LSP.Test
import Language.Haskell.LSP.Types
import Test.Hls.Util
import Test.Tasty
import Test.Tasty.ExpectedFailure (ignoreTestBecause)
import Test.Tasty.HUnit
import Test.Hspec.Expectations

tests :: TestTree
tests = testGroup "format document" [
    ignoreTestBecause "Broken" $ testCase "works" $ runSession hieCommand fullCaps "test/testdata" $ do
        doc <- openDoc "Format.hs" "haskell"
        formatDoc doc (FormattingOptions 2 True)
        documentContents doc >>= liftIO . (`shouldBe` formattedDocTabSize2)
    , ignoreTestBecause "Broken" $ testCase "works with custom tab size" $ runSession hieCommand fullCaps "test/testdata" $ do
        doc <- openDoc "Format.hs" "haskell"
        formatDoc doc (FormattingOptions 5 True)
        documentContents doc >>= liftIO . (`shouldBe` formattedDocTabSize5)
    , rangeTests
    , providerTests
    , stylishHaskellTests
    , brittanyTests
    , ormoluTests
    ]

rangeTests :: TestTree
rangeTests = testGroup "format range" [
    ignoreTestBecause "Broken" $ testCase "works" $ runSession hieCommand fullCaps "test/testdata" $ do
        doc <- openDoc "Format.hs" "haskell"
        formatRange doc (FormattingOptions 2 True) (Range (Position 1 0) (Position 3 10))
        documentContents doc >>= liftIO . (`shouldBe` formattedRangeTabSize2)
    , ignoreTestBecause "Broken" $ testCase "works with custom tab size" $ runSession hieCommand fullCaps "test/testdata" $ do
        doc <- openDoc "Format.hs" "haskell"
        formatRange doc (FormattingOptions 5 True) (Range (Position 4 0) (Position 7 19))
        documentContents doc >>= liftIO . (`shouldBe` formattedRangeTabSize5)
    ]

providerTests :: TestTree
providerTests = testGroup "formatting provider" [
    testCase "respects none" $ runSessionWithConfig (formatConfig "none") hieCommand fullCaps "test/testdata" $ do
        doc <- openDoc "Format.hs" "haskell"
        orig <- documentContents doc

        formatDoc doc (FormattingOptions 2 True)
        documentContents doc >>= liftIO . (`shouldBe` orig)

        formatRange doc (FormattingOptions 2 True) (Range (Position 1 0) (Position 3 10))
        documentContents doc >>= liftIO . (`shouldBe` orig)

    , ignoreTestBecause "Broken" $ testCase "can change on the fly" $ runSession hieCommand fullCaps "test/testdata" $ do
        doc <- openDoc "Format.hs" "haskell"

        sendNotification WorkspaceDidChangeConfiguration (DidChangeConfigurationParams (formatLspConfig "brittany"))
        formatDoc doc (FormattingOptions 2 True)
        documentContents doc >>= liftIO . (`shouldBe` formattedDocTabSize2)

        sendNotification WorkspaceDidChangeConfiguration (DidChangeConfigurationParams (formatLspConfig "floskell"))
        formatDoc doc (FormattingOptions 2 True)
        documentContents doc >>= liftIO . (`shouldBe` formattedFloskell)

        sendNotification WorkspaceDidChangeConfiguration (DidChangeConfigurationParams (formatLspConfig "brittany"))
        formatDoc doc (FormattingOptions 2 True)
        documentContents doc >>= liftIO . (`shouldBe` formattedBrittanyPostFloskell)
    ]

stylishHaskellTests :: TestTree
stylishHaskellTests = testGroup "stylish-haskell" [
  testCase "formats a file" $ runSession hieCommand fullCaps "test/testdata" $ do
      sendNotification WorkspaceDidChangeConfiguration (DidChangeConfigurationParams (formatLspConfig "stylish-haskell"))
      doc <- openDoc "StylishHaskell.hs" "haskell"
      formatDoc doc (FormattingOptions 2 True)
      contents <- documentContents doc
      liftIO $ contents `shouldBe`
        "import           Data.Char\n\
        \import qualified Data.List\n\
        \import           Data.String\n\
        \\n\
        \bar :: Maybe (Either String Integer) -> Integer\n\
        \bar Nothing          = 0\n\
        \bar (Just (Left _))  = 0\n\
        \bar (Just (Right x)) = x\n"
  , testCase "formats a range" $ runSession hieCommand fullCaps "test/testdata" $ do
      sendNotification WorkspaceDidChangeConfiguration (DidChangeConfigurationParams (formatLspConfig "stylish-haskell"))
      doc <- openDoc "StylishHaskell.hs" "haskell"
      formatRange doc (FormattingOptions 2 True) (Range (Position 0 0) (Position 2 21))
      contents <- documentContents doc
      liftIO $ contents `shouldBe`
        "import           Data.Char\n\
        \import qualified Data.List\n\
        \import           Data.String\n\
        \\n\
        \bar :: Maybe (Either String Integer) -> Integer\n\
        \bar Nothing = 0\n\
        \bar (Just (Left _)) = 0\n\
        \bar (Just (Right x)) = x\n"
  ]

brittanyTests :: TestTree
brittanyTests = testGroup "brittany" [
    ignoreTestBecause "Broken" $ testCase "formats a document with LF endings" $ runSession hieCommand fullCaps "test/testdata" $ do
        doc <- openDoc "BrittanyLF.hs" "haskell"
        let opts = DocumentFormattingParams doc (FormattingOptions 4 True) Nothing
        ResponseMessage _ _ (Right edits) <- request TextDocumentFormatting opts
        liftIO $ edits `shouldBe` [TextEdit (Range (Position 0 0) (Position 3 0))
                                    "foo :: Int -> String -> IO ()\nfoo x y = do\n    print x\n    return 42\n"]

    , ignoreTestBecause "Broken" $ testCase "formats a document with CRLF endings" $ runSession hieCommand fullCaps "test/testdata" $ do
        doc <- openDoc "BrittanyCRLF.hs" "haskell"
        let opts = DocumentFormattingParams doc (FormattingOptions 4 True) Nothing
        ResponseMessage _ _ (Right edits) <- request TextDocumentFormatting opts
        liftIO $ edits `shouldBe` [TextEdit (Range (Position 0 0) (Position 3 0))
                                    "foo :: Int -> String -> IO ()\nfoo x y = do\n    print x\n    return 42\n"]

    , ignoreTestBecause "Broken" $ testCase "formats a range with LF endings" $ runSession hieCommand fullCaps "test/testdata" $ do
        doc <- openDoc "BrittanyLF.hs" "haskell"
        let range = Range (Position 1 0) (Position 2 22)
            opts = DocumentRangeFormattingParams doc range (FormattingOptions 4 True) Nothing
        ResponseMessage _ _ (Right edits) <- request TextDocumentRangeFormatting opts
        liftIO $ edits `shouldBe` [TextEdit (Range (Position 1 0) (Position 3 0))
                                        "foo x y = do\n    print x\n    return 42\n"]

    , ignoreTestBecause "Broken" $ testCase "formats a range with CRLF endings" $ runSession hieCommand fullCaps "test/testdata" $ do
        doc <- openDoc "BrittanyCRLF.hs" "haskell"
        let range = Range (Position 1 0) (Position 2 22)
            opts = DocumentRangeFormattingParams doc range (FormattingOptions 4 True) Nothing
        ResponseMessage _ _ (Right edits) <- request TextDocumentRangeFormatting opts
        liftIO $ edits `shouldBe` [TextEdit (Range (Position 1 0) (Position 3 0))
                                        "foo x y = do\n    print x\n    return 42\n"]
    ]

ormoluTests :: TestTree
ormoluTests = testGroup "ormolu" [
    ignoreTestBecause "Broken" $ testCase "formats correctly" $ runSession hieCommand fullCaps "test/testdata" $ do
        let formatLspConfig provider =
                object [ "languageServerHaskell" .= object ["formattingProvider" .= (provider :: Value)] ]
        sendNotification WorkspaceDidChangeConfiguration (DidChangeConfigurationParams (formatLspConfig "ormolu"))
        doc <- openDoc "Format.hs" "haskell"
        formatDoc doc (FormattingOptions 2 True)
        docContent <- documentContents doc
        let formatted = liftIO $ docContent `shouldBe` formattedOrmolu
        case ghcVersion of
            GHC88 -> formatted
            GHC86 -> formatted
            _ -> liftIO $ docContent `shouldBe` unchangedOrmolu
    ]


formatLspConfig :: Value -> Value
formatLspConfig provider = object [ "languageServerHaskell" .= object ["formattingProvider" .= (provider :: Value)] ]

formatConfig :: Value -> SessionConfig
formatConfig provider = defaultConfig { lspConfig = Just (formatLspConfig provider) }


formattedDocTabSize2 :: T.Text
formattedDocTabSize2 =
  "module Format where\n\
  \foo :: Int -> Int\n\
  \foo 3 = 2\n\
  \foo x = x\n\
  \bar :: String -> IO String\n\
  \bar s = do\n\
  \  x <- return \"hello\"\n\
  \  return \"asdf\"\n\n\
  \data Baz = Baz { a :: Int, b :: String }\n\n"

formattedDocTabSize5 :: T.Text
formattedDocTabSize5 =
  "module Format where\n\
  \foo :: Int -> Int\n\
  \foo 3 = 2\n\
  \foo x = x\n\
  \bar :: String -> IO String\n\
  \bar s = do\n\
  \     x <- return \"hello\"\n\
  \     return \"asdf\"\n\n\
  \data Baz = Baz { a :: Int, b :: String }\n\n"

formattedRangeTabSize2 :: T.Text
formattedRangeTabSize2 =
  "module    Format where\n\
  \foo :: Int -> Int\n\
  \foo 3 = 2\n\
  \foo x = x\n\
  \bar   :: String ->   IO String\n\
  \bar s =  do\n\
  \      x <- return \"hello\"\n\
  \      return \"asdf\"\n\
  \\n\
  \data Baz = Baz { a :: Int, b :: String }\n\n"

formattedRangeTabSize5 :: T.Text
formattedRangeTabSize5 =
  "module    Format where\n\
  \foo   :: Int ->  Int\n\
  \foo  3 = 2\n\
  \foo    x  = x\n\
  \bar :: String -> IO String\n\
  \bar s = do\n\
  \     x <- return \"hello\"\n\
  \     return \"asdf\"\n\
  \\n\
  \data Baz = Baz { a :: Int, b :: String }\n\n"

formattedFloskell :: T.Text
formattedFloskell =
  "module Format where\n\
  \\n\
  \foo :: Int -> Int\n\
  \foo 3 = 2\n\
  \foo x = x\n\
  \\n\
  \bar :: String -> IO String\n\
  \bar s = do\n\
  \  x <- return \"hello\"\n\
  \  return \"asdf\"\n\n\
  \data Baz = Baz { a :: Int, b :: String }\n\n"

formattedBrittanyPostFloskell :: T.Text
formattedBrittanyPostFloskell =
  "module Format where\n\
  \\n\
  \foo :: Int -> Int\n\
  \foo 3 = 2\n\
  \foo x = x\n\
  \\n\
  \bar :: String -> IO String\n\
  \bar s = do\n\
  \  x <- return \"hello\"\n\
  \  return \"asdf\"\n\n\
  \data Baz = Baz { a :: Int, b :: String }\n\n"

formattedOrmolu :: T.Text
formattedOrmolu =
  "module Format where\n\
  \\n\
  \foo :: Int -> Int\n\
  \foo 3 = 2\n\
  \foo x = x\n\
  \\n\
  \bar :: String -> IO String\n\
  \bar s = do\n\
  \  x <- return \"hello\"\n\
  \  return \"asdf\"\n\n\
  \data Baz = Baz {a :: Int, b :: String}\n"

unchangedOrmolu :: T.Text
unchangedOrmolu =
  "module    Format where\n\
  \foo   :: Int ->  Int\n\
  \foo  3 = 2\n\
  \foo    x  = x\n\
  \bar   :: String ->   IO String\n\
  \bar s =  do\n\
  \      x <- return \"hello\"\n\
  \      return \"asdf\"\n\
  \\n\
  \data Baz = Baz { a :: Int, b :: String }\n\n"
