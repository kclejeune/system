# Nix System Configuration

[![Build Status](https://api.cirrus-ci.com/github/kclejeune/system.svg?branch=master)](https://cirrus-ci.com/github/kclejeune/system)

This repository manages system configurations for all of my
macOS, nixOS, and linux machines.

## Structure

This repository is a [flake](https://nixos.wiki/wiki/Flakes). All system configurations are defined
in [flake.nix](./flake.nix). Platform specific configurations are found defined in the flake outputs
`darwinConfigurations`, `nixosConfigurations` for macOS and NixOS respectively.

### Overlapping Nix-Darwin and NixOS

Nix-Darwin and NixOS configurations share as much overlap as possible in the common module, [./modules/common.nix](./modules/common.nix).
Platform specific modules add onto the common module in [./modules/darwin/default.nix](./modules/darwin/default.nix) and [./modules/nixos/default.nix](./modules/nixos/default.nix) for macOS and NixOS respectively.

### Decoupled Home Manager Configuration

My home-manager configuration is entirely decoupled from NixOS and nix-darwin configurations.
This means that all of its modules are found in [./modules/home-manager](./modules/home-manager).
These modules are imported into all other configurations in the common module similarly to this:

```nix
{ config, pkgs, ... }: {
  home-manager.users.kclejeune = import ./home-manager/home.nix;
}
```

This means that [home.nix](./modules/home-manager/home.nix) is fully compatible as a standalone configuration, managed with the `home-manager` CLI.
This allows close replication of any user config for any linux system running nix. These configurations are defined in the `homeConfigurations` output.

### User Customization

User "profiles" are specified in [./profiles](./profiles); these modules configure
contextual, identity-specific settings such as SSL certificates or work vs. personal email addresses.
When possible, home-manager functionality is extracted into [./profiles/home-manager](./profiles/home-manager), as mentioned previously

## Installing a Configuration

### Non-NixOS Prerequisite: Install Nix Package Manager

Run the installer script to perform a multi-user installation on darwin or linux:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

Note that this step is naturally skipped on NixOS since `nix` is the package manager by default.

## System Bootstrapping

### NixOS

Follow the installation instructions, then run

```bash
sudo nixos-install --flake github:kclejeune/system#phil
```

### Darwin/Linux

Clone this repository into `~/.nixpkgs` with

```bash
git clone https://github.com/kclejeune/system ~/.nixpkgs
```

You can bootstrap a new system with the `bootstrap` command:

```bash
nix run .#sysdo bootstrap
```

This will attempt to detect the host system and install nix-darwin or home-manager, but this behavior can be overridden using the `--darwin` or `--home-manager` flags.

## `sysdo` CLI

The `sysdo` utility is a python script that wraps `nix`, `darwin-rebuild`, `nixos-rebuild`,
and `home-manager` commands to provide a consistent interface across multiple platforms. It has some dependencies which are defined in the `devShell`
flake output. Source for this tool is found in [bin/sysdo.py](./bin/sysdo.py).
