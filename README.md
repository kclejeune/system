# Nix System Configuration

![system build](https://github.com/kclejeune/system/workflows/system%20build/badge.svg)

This repository manages system configurations for all of my
macOS, nixOS, and linux machines.

## Structure

This repository is a flake, so configurations are specified
in [flake.nix](./flake.nix). Machine specific configurations are found
in [./machines](./machines), sharing as much functionality as
possible in [./machines/common.nix](./machines/common.nix).

## Prerequisites
### Installing Nix Package Manager

Run the installer script to perform a multi-user installation
on darwin or any other type of linux.

```bash
./install-nix.sh
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

You can bootstrap a new nix-darwin system using

```bash
nix develop -c ./do disksetup && ./do build --darwin [host] && ./result/activate-user && ./result/activate
```

or a home-manager configuration using

```bash
nix develop -c ./do build --home-manager [host] && ./result/activate
```
