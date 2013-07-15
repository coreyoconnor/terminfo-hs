{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE RecordWildCards #-}

-- |
-- Module      :  System.Terminfo.DirTreeDB
-- Copyright   :  (c) Bryan Richter (2013)
-- License     :  BSD-style
-- 
-- Maintainer  :  bryan.richter@gmail.com
--
-- An internal module encapsulating methods for parsing a terminfo file as
-- generated by tic(1). The primary reference is the term(5) manpage.
--

module System.Terminfo.DirTreeDB
    ( parseDirTreeDB
    ) where

import Control.Applicative ((<$>), (<*>))
import Control.Monad (when, void)
import Data.Attoparsec as A
import Data.ByteString (ByteString)
import qualified Data.ByteString as B
import Data.Char (chr)
import Data.List (foldl')
import Data.Maybe (catMaybes)
import Data.Monoid (mconcat)
import Data.Word (Word16)

import System.Terminfo.Types
import System.Terminfo.TH

-- | term(5) defines a short integer as two 8-bit bytes, so:
type ShortInt = Word16

-- | short ints are stored little-endian.
shortInt :: Integral a => ShortInt -> Parser a
shortInt i = word8 first >> word8 second >> return (fromIntegral i)
  where
    (second', first') = i `divMod` 256
    second = fromIntegral second'
    first = fromIntegral first'

-- | short ints are stored little-endian.
--
-- (-1) is represented by the two bytes 0o377 0o377.
--
-- Return type is Int so I can include (-1) in the possible outputs. I
-- wonder if I will regret this.
anyShortInt :: Parser Int
anyShortInt = do
    first <- fromIntegral <$> anyWord8
    second <- fromIntegral <$> anyWord8
    return $ if first == 0o377 && second == 0o377
       then (-1)
       else 256*second + first

parseDirTreeDB :: ByteString -> Either String TIDatabase
parseDirTreeDB = parseOnly tiDatabase

tiDatabase :: Parser TIDatabase
tiDatabase = do
    Header{..} <- header
    -- Ignore names
    _ <- A.take namesSize
    bools <- boolCaps boolSize
    -- Align on an even byte
    when (odd boolSize) (void $ A.take 1)
    nums <- numCaps numIntegers
    strs <- stringCaps numOffsets stringSize
    -- TODO: extended info
    return $ mconcat [bools, nums, strs]

boolCaps :: Int -> Parser TIDatabase
boolCaps sz = do
    bytes <- B.unpack <$> A.take sz
    let setters = zipWith fixVal bytes $mkBoolSetters
    return $ foldl' (flip ($)) ($mkBoolCapsMempty) setters
  where
    fixVal b f = f $ b == 1

numCaps :: Int -> Parser TIDatabase
numCaps cnt = do
    ints <- map maybePositive <$> A.count cnt anyShortInt
    let setters = zipWith ($) $mkNumSetters ints
    return $ foldl' (flip ($)) ($mkNumCapsMempty) setters

stringCaps :: Int -> Int -> Parser TIDatabase
stringCaps numOffsets stringSize = do
    offs <- map maybePositive <$> A.count numOffsets anyShortInt
    stringTable <- A.take stringSize
    let values = map (parseStringMay stringTable) offs
        setters = zipWith ($) $mkStrSetters values
    return $ foldl' (flip ($)) ($mkStrCapsMempty) setters
  where
    parseStringMay :: ByteString -> Maybe Int -> Maybe String
    parseStringMay = fmap . flip parseString

    parseString :: Int -> ByteString -> String
    parseString offset = asString . B.takeWhile (/= 0) . B.drop offset
      where
        asString = map (chr . fromIntegral) . B.unpack

maybePositive :: Int -> Maybe Int
maybePositive i = if i /= (-1)
                    then Just i
                    else Nothing

-- | the magic number for term files
magic :: Parser Int
magic = shortInt 0o432 <?> "Not a terminfo file (bad magic)"

data Header = Header
     { namesSize :: Int
     , boolSize :: Int
     , numIntegers :: Int
     , numOffsets :: Int
     , stringSize :: Int
     }
     deriving (Show)

header :: Parser Header
header = magic >> Header <$> anyShortInt
                         <*> anyShortInt
                         <*> anyShortInt
                         <*> anyShortInt
                         <*> anyShortInt
