{-# LANGUAGE CPP #-}
module Distribution.Dev.InitPkgDb
    ( initPkgDb
    )
where

import Control.Monad ( unless )
import qualified Distribution.Verbosity as V
import Distribution.Version ( Version(..) )
import Distribution.Simple.Program ( ghcPkgProgram, requireProgram, programVersion, ConfiguredProgram, runProgram )
#if MIN_VERSION_Cabal(1,8,0)
import Distribution.Simple.Program.Db ( emptyProgramDb )
#elif MIN_VERSION_Cabal(1,6,0)
import Distribution.Simple.Program ( emptyProgramConfiguration )
import Distribution.Version ( VersionRange(AnyVersion) )
#endif
import System.Directory ( doesFileExist, doesDirectoryExist )

import Distribution.Dev.LocalRepo ( Sandbox, pkgConf )

data PackageDbType = FileDb | DirDb

ghcPackageDbType :: ConfiguredProgram -> PackageDbType
ghcPackageDbType p = case programVersion p of
                       Nothing -> error "Unknown ghc version!"
                       Just v | v < Version [6, 12] [] -> FileDb
                              | otherwise              -> DirDb

-- |Initialize a package database.
--
-- XXX: This is GHC-only. Perhaps we can take advantage of the Cabal
-- package database work.
--
-- XXX: If a compilation happens in a sandbox for that was used for a
-- GHC version with a different package config type, this function
-- will just fail. Ideally, we'd have different package DBs for
-- different GHC versions, but the cabal-install config file just sets
-- one location. We'd have to have the GHC version before writing the
-- cabal config file.
initPkgDb :: Sandbox -> IO ()
initPkgDb s = do
#if MIN_VERSION_Cabal(1,8,0)
  (ghcPkg, _) <- requireProgram V.normal ghcPkgProgram emptyProgramDb
#elif MIN_VERSION_Cabal(1,6,0)
  (ghcPkg, _) <- requireProgram anyVersion V.normal ghcPkgProgram emptyProgramConfiguration
#endif
  case ghcPackageDbType ghcPkg of
    FileDb -> do
      e <- doesFileExist (pkgConf s)
      unless e $ writeFile (pkgConf s) $ show ([] :: [()])
    DirDb  -> do
      e <- doesDirectoryExist (pkgConf s)
      unless e $ runProgram V.normal ghcPkg ["init", pkgConf s]
