🍱 miso-sampler 
====================

This project contains a sample [miso](https://github.com/dmjio/miso) application with scripts to 
develop against vanilla GHC and cabal to compile to Web Assembly or JavaScript.

### Source

View [source](https://github.com/haskell-miso/miso-sampler/blob/main/app/Main.hs).

# Cabal Workflow

The ``build.hs`` script manages the setup of the environment and execution of specific cabal targets. Everything it does are just minor tweaks to what the original Makefile in the Nix version does to get things to work outside of a nix environment.

Development can be performed as with any other cabal project but this script will need to be used to generate the WASM/JS outputs.

There are multiple cabal project file files depending on if the build is done with the WASM GHC compiler or just GHC to support development with ``cabal run``. This is to allow for a different cabal freeze file the two build types.

## Prerequisites

A working [GHCup](https://www.haskell.org/ghcup/) installation

# Building and running

The build script is a cabal script that can be run from the shell. 

Run the build script like so:

```
./build.hs <command>
```

More help is available by running

```
./build.hs --help
```

## Commands
### installghc 

Uses the instructions are from the [GHC WASM installation](https://gitlab.haskell.org/haskell-wasm/ghc-wasm-meta#using-ghcup) to set up and install a WASM enabled GHC to be managed by GHCup.
    
### clean

Runs ``cabal clean`` and removes the ``public/`` directory.

### build

Runs cabal build to build the wasm file and then uses the same process as in the make file to find it and copy it to ``public/``

### serve

Runs ``npx http-server public`` to serve the ``public/`` directory

### browsermode

Starts an interactive session as per the Nix version's Makefile to run with ghci and the browser. See the README for more on what can be done in Browser mode 🔥
