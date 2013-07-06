{-# LANGUAGE TemplateHaskell #-}

-- |
-- Module      :  Terminfo.DirTreeDB
-- Copyright   :  (c) Bryan Richter (2013)
-- License     :  BSD-style
-- 
-- Maintainer  :  bryan.richter@gmail.com
-- Portability :  portable
--
-- An internal module encapsulating methods for parsing a terminfo file as
-- generated by tic(1). The primary reference is the term(5) manpage.

module Terminfo.DirTreeDB
    ( parseDirTreeDB
    ) where

import Development.Placeholders

import Data.ByteString (ByteString)

import Terminfo.Internal

parseDirTreeDB :: ByteString -> Either String TIDatabase
parseDirTreeDB = $notImplemented
