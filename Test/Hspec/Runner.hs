
-- | This module contains the runners that take a set of specs, evaluate their examples, and
-- report to a given handle.
--
module Test.Hspec.Runner (
  Specs, hspec, hspecX, hspecB, hHspec, hHspecWithFormat, describe, it, toExitCode
) where

import Test.Hspec.Core
import Test.Hspec.Formatters
import System.IO
import System.CPUTime (getCPUTime)
import Control.Monad (when)
import System.Exit
import Control.Exception (bracket_)

type Specs = [Spec]

-- | Evaluate and print the result of checking the spec examples.
runFormatter :: Formatter -> Handle -> String -> [String] -> Specs -> IO Specs
runFormatter formatter h _     errors []     = do
  errorsFormatter formatter h (reverse errors)
  return []
runFormatter formatter h group errors (iospec:ioss) = do
  spec <- evaluateSpec iospec
  when (group /= name spec) (exampleGroupStarted formatter h spec)
  case result spec of
    (Success  ) -> examplePassed formatter h spec errors
    (Fail _   ) -> exampleFailed formatter h spec errors
    (Pending _) -> examplePending formatter h spec errors
  let errors' = if isFailure (result spec)
                then errorDetails spec (length errors) : errors
                else errors
  specs <- runFormatter formatter h (name spec) errors' ioss
  return $ spec : specs

errorDetails :: Spec -> Int -> String
errorDetails spec i = case result spec of
  (Fail s   ) -> concat [ show (i + 1), ") ", name spec, " ",  requirement spec, " FAILED", if null s then "" else "\n" ++ s ]
  _           -> ""

-- | Use in place of @hspec@ to also exit the program with an @ExitCode@
hspecX :: Specs -> IO a
hspecX ss = hspecB ss >>= exitWith . toExitCode

-- | Use in place of hspec to also give a @Bool@ success indication
hspecB :: Specs -> IO Bool
hspecB ss = hspec ss >>= return . success

-- | Create a document of the given specs and write it to stdout.
hspec :: Specs -> IO [Spec]
hspec ss = hHspec stdout ss

-- | Create a document of the given specs and write it to the given handle.
--
-- > writeReport filename specs = withFile filename WriteMode (\ h -> hHspec h specs)
--
hHspec :: Handle -> Specs -> IO Specs
hHspec h specs = do
  useColor <- hIsTerminalDevice h
  hHspecWithFormat (specdoc useColor) h specs

-- | Create a document of the given specs and write it to the given handle.
-- THIS IS LIKELY TO CHANGE
hHspecWithFormat :: Formatter -> Handle -> Specs -> IO Specs
hHspecWithFormat formatter h ss =
  bracket_ (when (usesFormatting formatter) $ restoreFormat h)
           (when (usesFormatting formatter) $ restoreFormat h)
           (do
         t0 <- getCPUTime
         specList <- runFormatter formatter h "" [] ss
         t1 <- getCPUTime
         let runTime = ((fromIntegral $ t1 - t0) / (10.0^(12::Integer)) :: Double)
         (footerFormatter formatter) h specList runTime
         return specList)

toExitCode :: Bool -> ExitCode
toExitCode True  = ExitSuccess
toExitCode False = ExitFailure 1

