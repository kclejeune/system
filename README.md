# Nix System Configuration

![system build](https://github.com/kclejeune/system/workflows/system%20build/badge.svg)

## Installing Nix Package Manager

Run the following to perform a multi-user installation for darwin or standard linux.
This step is naturally skipped on NixOS since `nix` is the package manager by default.

### macOS

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon --darwin-use-unencrypted-nix-store-volume
```

### Linux

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
```

## System Bootstrapping

Clone this repository into `~/.nixpkgs` with

```bash
git clone https://github.com/kclejeune/system ~/.nixpkgs
```

You can bootstrap a new system using

```bash
cd ~/.nixpkgs && nix-shell --run "darwinInstall"
```

or run the build only by running

```bash
cd ~/.nixpkgs && nix-shell --run "darwinTest"
```

## Installing Homebrew dependencies

The few leftover homebrew packages and brew casks are stored in `~/Brewfile`. They can be installed using `cd ~ && brew bundle`.
