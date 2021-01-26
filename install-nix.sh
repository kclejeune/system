#! /usr/bin/env sh

if [[ $(uname -s) = "Darwin" ]]; then
    FLAG="--darwin-use-unencrypted-nix-store-volume"
else
    FLAG=""
fi

if [[ ! -z "$1"]]; then
    URL=$1
else
    URL="https://github.com/numtide/nix-flakes-installer/releases/download/nix-2.4pre20210122_b7bfc7e/install"
fi

sh <(curl -L $URL) --daemon $FLAG
