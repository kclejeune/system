#! /usr/bin/env bash

URL="https://nixos.org/nix/install"

# install using workaround for darwin systems
if [[ $(uname -s) = "Darwin" ]]; then
    FLAG="--darwin-use-unencrypted-nix-store-volume"
fi

[[ -n "$1" ]] && URL="$1"

if command -v nix >/dev/null; then
    echo "nix is already installed on this system."
else
    bash <(curl -L "$URL") --daemon $FLAG
fi

NIX_CONF_PATH="$HOME/.config/nix"
mkdir -p "$NIX_CONF_PATH"

if [[ ! -f $NIX_CONF_PATH/nix.conf ]] || ! grep "experimental-features" <"$NIX_CONF_PATH"; then
    echo "experimental-features = nix-command flakes" | tee -a "$NIX_CONF_PATH"/nix.conf
fi
