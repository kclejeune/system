# MacOS System Configuration with Nix

[![Build Status](https://travis-ci.com/kclejeune/dotfiles.svg?branch=master)](https://travis-ci.com/kclejeune/dotfiles)

## Installing Nix Package Manager

Run the following to perform a multi-user installation for darwin or standard linux. This step is skipped on NixOS.

```bash
if [[ $(uname -s) == 'Darwin' ]]; then
    sh <(curl https://nixos.org/nix/install) --daemon --darwin-use-unencrypted-nix-store-volume
else
    sh <(curl https://nixos.org/nix/install) --daemon
fi
```

## Cloning Dotfiles

Clone this repository into `~/.nixpkgs` with

```
git clone https://github.com/kclejeune/system ~/.nixpkgs
```

Install nix-darwin and home-manager. Then, run `darwin-rebuild switch`.

## Installing Homebrew dependencies

The few leftover homebrew packages and brew casks are stored in `~/Brewfile`. They can be installed using `cd ~ && brew bundle`.
