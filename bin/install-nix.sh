#! /usr/bin/env bash

RELEASE="nix-2.5pre20211019_4a2b7cc"
URL="https://github.com/numtide/nix-unstable-installer/releases/download/$RELEASE/install"

# install using workaround for darwin systems
if [[ $(uname -s) = "Darwin" ]]; then
    FLAG="--darwin-use-unencrypted-nix-store-volume"
fi

[[ ! -z "$1" ]] && URL="$1"

if command -v nix > /dev/null; then
    echo "nix is already installed on this system."
else
    bash <(curl -L $URL) --daemon $FLAG
fi

NIX_CONF_PATH=$HOME/.config/nix
if [[ ! -d $NIX_CONF_PATH ]]; then
    mkdir -p $NIX_CONF_PATH
fi

if [[ ! -f $NIX_CONF_PATH/nix.conf ]] || ! grep "experimental-features" < $NIX_CONF_PATH; then
    echo "experimental-features = nix-command flakes" | tee -a $NIX_CONF_PATH/nix.conf
fi


