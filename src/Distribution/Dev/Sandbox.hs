{-# LANGUAGE GADTs, EmptyDataDecls #-}
module Distribution.Dev.Sandbox
    ( defaultSandbox
    , resolveSandbox
    , getSandbox
    , Sandbox
    , localRepoPath
    , pkgConf
    , cabalConf
    , PackageDbType(..)
    , setVersion
    , getVersion
    , UnknownVersion
    , KnownVersion
    )
where

import Data.Maybe ( listToMaybe )
import qualified Distribution.Dev.Flags as F ( GlobalFlag(Sandbox), getVerbosity )
import Distribution.Simple.Utils ( debug )
import System.Directory ( canonicalizePath, createDirectoryIfMissing )
import System.FilePath ( (</>) )

-- A sandbox directory that we may or may not know what kind of
-- package format it uses
data UnknownVersion
data KnownVersion

data Sandbox a where
    UnknownVersion :: FilePath -> Sandbox UnknownVersion
    KnownVersion :: FilePath -> PackageDbType -> Sandbox KnownVersion

data PackageDbType = GHC_6_8_Db FilePath | GHC_6_10_Db | GHC_6_12_Db

-- NOTE: GHC < 6.12: compilation warnings about non-exhaustive pattern
-- matches are spurious (we'd get a type error if we tried to make
-- them complete!)
setVersion :: Sandbox UnknownVersion -> PackageDbType -> Sandbox KnownVersion
setVersion (UnknownVersion p) ty = KnownVersion p ty

getVersion :: Sandbox KnownVersion -> PackageDbType
getVersion (KnownVersion _ db) = db

sandbox :: Sandbox a -> FilePath
sandbox (UnknownVersion p) = p
sandbox (KnownVersion p _) = p

sPath :: FilePath -> Sandbox a -> FilePath
sPath p s = sandbox s </> p

localRepoPath :: Sandbox a -> FilePath
localRepoPath = sPath "packages"

pkgConf :: Sandbox KnownVersion -> FilePath
pkgConf s@(KnownVersion _ ty) = sPath (packageDbName ty) s
    where
      packageDbName (GHC_6_8_Db _) = "packages-6.8.conf"
      packageDbName GHC_6_10_Db = "packages-6.10.conf"
      packageDbName GHC_6_12_Db = "packages.conf.d"

cabalConf :: Sandbox a -> FilePath
cabalConf = sPath "cabal.config"

defaultSandbox :: FilePath
defaultSandbox = "./cabal-dev"

getSandbox :: [F.GlobalFlag] -> Maybe FilePath
getSandbox flgs = listToMaybe [ fn | F.Sandbox fn <- flgs ]

resolveSandbox :: [F.GlobalFlag] -> IO (Sandbox UnknownVersion)
resolveSandbox flgs = do
  relSandbox <-
      case getSandbox flgs of
        Nothing -> do
          debug (F.getVerbosity flgs) $
                    "No local repository specified. Using " ++ defaultSandbox
          return defaultSandbox
        Just s -> return $ s

  localRepo <- canonicalizePath relSandbox
  debug (F.getVerbosity flgs) $
            "Using " ++ localRepo ++ " as the local repository path"
  createDirectoryIfMissing True localRepo
  return $ UnknownVersion localRepo
