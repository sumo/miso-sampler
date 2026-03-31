#!/usr/bin/env -S cabal +RTS -N4 -RTS

{- cabal:

build-depends: base
  , turtle
  , relude
  , foldl
  , optparse-applicative
ghc-options:
    -Wall -threaded -rtsopts -with-rtsopts=-N -with-rtsopts=-T
mixins:
    base hiding (Prelude),
    relude (Relude as Prelude),
    relude,
-}
{-# LANGUAGE OverloadedStrings #-}

import qualified Control.Foldl as Fold
import Options.Applicative
  ( Parser,
    ParserInfo,
    command,
    execParser,
    header,
    help,
    helper,
    hsubparser,
    info,
    long,
    progDesc,
    showDefault,
    strOption,
    value,
  )
import Turtle as T
  ( Line,
    Shell,
    cp,
    cptree,
    die,
    echo,
    export,
    fold,
    inproc,
    inshell,
    lineToText,
    mktree,
    procs,
    rmtree,
    sh,
    shells,
    single,
    stdin,
    strict,
    testfile,
    unsafeTextToLine,
  )

type Version = Text

data Command
  = InstallGHCWASM
  | Clean
  | Build
  | Serve
  | BrowserMode
  | Freeze

data Args = Args
  { ghcVersion :: Version,
    cmd :: Command
  }

commands :: Parser Command
commands =
  hsubparser
    ( command "installghc" (info (pure InstallGHCWASM) (progDesc "Setup GHCup to install and manage GHC WASM"))
        <> command "clean" (info (pure Clean) (progDesc "Clean the project build"))
        <> command "build" (info (pure Build) (progDesc "Build WASM output and package to public/"))
        <> command "serve" (info (pure Serve) (progDesc "Serve the application from ./public using http-server"))
        <> command "browsermode" (info (pure BrowserMode) (progDesc "Run the application in GHCi and the browser"))
        <> command "freeze" (info (pure Freeze) (progDesc "Freeze the application dependencies file for the build ghc version"))
    )

scriptArgs :: Parser Args
scriptArgs =
  Args
    <$> strOption
      ( long "ghc-ver"
          <> help
            "Version of GHC WASM to use"
          <> showDefault
          <> value "9.12"
      )
    <*> commands

opts :: ParserInfo Args
opts =
  info
    (scriptArgs <**> helper)
    ( progDesc "Build miso application"
        <> header "Miso Sampler"
    )

main :: IO ()
main = do
  rgs <- execParser opts
  case cmd rgs of
    InstallGHCWASM -> install rgs
    Build -> build (wasmCabalInProc (ghcVersion rgs)) (wasmGHC (ghcVersion rgs))
    Serve -> shells "npx http-server public" mempty
    BrowserMode -> sh $ do
      exportNodePath
      wasmCabalInteractive
        (ghcVersion rgs)
        [ "repl",
          "-finteractive",
          "--repl-options=-fghci-browser -fghci-browser-host=127.0.0.1",
          "--enable-shared",
          "app"
        ]
    Clean -> do
      rmtree "public"
      shells "cabal clean" mempty
    Freeze -> sh $ do
      exists <- testfile ("wasm-" <> toString (ghcVersion rgs) <> ".cabal.project")
      if exists
        then do
          inshellIgnore ". ~/.ghc-wasm/env" mempty
          wasmCabalInteractive
            (ghcVersion rgs)
            [ "freeze",
              "--project-file=wasm-" <> ghcVersion rgs <> ".cabal.project"
            ]
        else
          echo ("No existing project file to freeze, create wasm-" <> unsafeTextToLine (ghcVersion rgs) <> ".cabal.project first")

install :: Args -> IO ()
install rgs = do
  sh $ do
    let outp = inshell "curl https://gitlab.haskell.org/haskell-wasm/ghc-wasm-meta/-/raw/master/bootstrap.sh" mempty
    inshellIgnore "SKIP_GHC=1 sh" outp
    inshellIgnore "ghcup config add-release-channel --force https://gitlab.haskell.org/haskell-wasm/ghc-wasm-meta/-/raw/master/ghcup-wasm-0.0.9.yaml" mempty
    inshellIgnore (". ~/.ghc-wasm/env && ghcup install ghc wasm32-wasi-" <> ghcVersion rgs <> " -- $CONFIGURE_ARGS") mempty

inshellIgnore :: Text -> Shell Line -> Shell ()
inshellIgnore txt = void . strict . inshell txt

build :: (MonadIO io, IsString a, IsString t) => ([a] -> Shell Line) -> (t -> Text) -> io ()
build wcab wghc = sh $ do
  inshellIgnore ". ~/.ghc-wasm/env" mempty
  _ <- strict $ wcab ["build"]
  mktree "public"
  cptree "static" "public"
  wasmlocm <- T.fold (wcab ["list-bin", "app"]) Fold.last
  case wasmlocm of
    Nothing -> T.die "cabal list-bin app failed to return a result"
    Just wasmloc -> do
      let wasmName = lineToText wasmloc
      echo ("Building using wasm " <> wasmloc)
      libdir <- single (inshell (wghc "--print-libdir") mempty)
      cp (toString wasmName) "public/app.wasm"
      inshellIgnore (". ~/.ghc-wasm/env" <> " && " <> lineToText libdir <> "/post-link.mjs -i " <> wasmName <> " -o public/ghc_wasm_jsffi.js") mempty

wasmCabalInProc :: Text -> [Text] -> Shell Line
wasmCabalInProc version rest =
  inproc
    "cabal"
    (wasmCabalParams version rest)
    mempty

wasmCabalInteractive :: (MonadIO io) => Text -> [Text] -> io ()
wasmCabalInteractive version rest =
  procs
    "cabal"
    (wasmCabalParams version rest)
    T.stdin

wasmCabalParams :: (Semigroup a, IsString a) => a -> [a] -> [a]
wasmCabalParams version rest =
  [ "--with-compiler=wasm32-wasi-ghc-" <> version,
    "--with-hc-pkg=wasm32-wasi-ghc-pkg-" <> version,
    "--with-hsc2hs=wasm32-wasi-hsc2hs-" <> version,
    "--with-haddock=wasm32-wasi-haddock-" <> version,
    "--project-file=wasm-" <> version <> ".cabal.project"
  ]
    <> rest

wasmGHC :: Text -> Text -> Text
wasmGHC ver rest = "wasm32-wasi-ghc-" <> ver <> " " <> rest

exportNodePath :: Shell ()
exportNodePath = do
  npmroot <- inshell "npm root -g" mempty
  export "NODE_PATH" (lineToText npmroot)
  inshellIgnore ". ~/.ghc-wasm/env" mempty