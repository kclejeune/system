# MacOS System Configuration with Nix

![nix-darwin system build](https://github.com/kclejeune/system/workflows/nix-darwin%20system%20build/badge.svg?branch=master)

## Installing Nix Package Manager

Run the following to perform a multi-user installation for darwin or standard linux. This step is skipped on NixOS.

```bash
if [[ $(uname -s) == 'Darwin' ]]; then
    sh <(curl -L https://nixos.org/nix/install) --daemon --darwin-use-unencrypted-nix-store-volume
else
    sh <(curl -L https://nixos.org/nix/install) --daemon
fi
```

## System Bootstrapping

Clone this repository into `~/.nixpkgs` with

```bash
git clone https://github.com/kclejeune/system ~/.nixpkgs
```

You can bootstrap a new system using

```bash
cd ~/.nixpkgs && nix develop --command "darwinInstall"
```

or run the build only with `darwinTest` instead of `darwinInstall`.

## Installing Homebrew dependencies

The few leftover homebrew packages and brew casks are stored in `~/Brewfile`. They can be installed using `cd ~ && brew bundle`.
