#! /usr/bin/env bash

# URL="https://nixos.org/nix/install"
URL="https://github.com/numtide/nix-flakes-installer/releases/download/nix-2.4pre20210126_f15f0b8/install"

# install using workaround for darwin systems
[[ $(uname -s) = "Darwin" ]] && FLAG="--darwin-use-unencrypted-nix-store-volume"
[[ ! -z "$1" ]] && URL="$1"

command -v nix > /dev/null && echo "nix is already installed on this system." || bash <(curl -L $URL) --daemon $FLAG
