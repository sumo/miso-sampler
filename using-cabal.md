# Workflow with just cabal

The sample app can be run without nix. Everything here is just minor tweaks to what the Makefile does to get things to work outside of a nix environment.

## Install WASI 

These instructions are from the [GHC WASM installation](https://gitlab.haskell.org/haskell-wasm/ghc-wasm-meta#using-ghcup)

```bash
curl https://gitlab.haskell.org/haskell-wasm/ghc-wasm-meta/-/raw/master/bootstrap.sh | SKIP_GHC=1 sh

source ~/.ghc-wasm/env

ghcup config add-release-channel https://gitlab.haskell.org/haskell-wasm/ghc-wasm-meta/-/raw/master/ghcup-wasm-0.0.9.yaml

ghcup install ghc wasm32-wasi-9.12 -- $CONFIGURE_ARGS
``` 
    
## Set up aliases

```
alias wasm32-wasi-cabal='cabal --with-compiler=wasm32-wasi-ghc-9.12 --with-hc-pkg=wasm32-wasi-ghc-pkg-9.12 --with-hsc2hs=wasm32-wasi-hsc2hs-9.12 --with-haddock=wasm32-wasi-haddock-9.12'

alias wasm32-wasi-ghc=wasm32-wasi-ghc-9.12

wasm32-wasi-cabal update
```

## Set up the environment

```
npm install -g ws
export NODE_PATH=$(npm root -g)
```

## Run the build and serve the application

```
wasm32-wasi-cabal build --enable-shared
rm -rf public
cp -r static public
```

### fish version
```fish
set my_wasm (wasm32-wasi-cabal list-bin app | tail -n 1)
eval (wasm32-wasi-ghc --print-libdir)/post-link.mjs --input $my_wasm --output public/ghc_wasm_jsffi.js
cp -v $my_wasm public/
```

### bash
```bash
$(eval my_wasm=$(shell wasm32-wasi-cabal list-bin app | tail -n 1))
$(shell wasm32-wasi-ghc --print-libdir)/post-link.mjs --input $(my_wasm) --output public/ghc_wasm_jsffi.js
cp -v $(my_wasm) public/
```

### Run HTTP server
```
npx http-server public
```

## Browser mode 🔥

As per the README run the following and click the link
```
wasm32-wasi-cabal repl app -finteractive --repl-options='-fghci-browser -fghci-browser-host=127.0.0.1' --enable-shared
```

