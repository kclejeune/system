# Nix System Configuration

[![Build Status](https://api.cirrus-ci.com/github/kclejeune/system.svg?branch=master)](https://cirrus-ci.com/github/kclejeune/system)

This repository manages system configurations for all of my macOS, NixOS, and
Linux machines.

## Structure

The flake follows the **dendritic pattern**: [`flake.nix`](./flake.nix) is a
tiny entry point that hands a [`flake-parts`](https://flake.parts) orchestrator
the recursively-discovered tree under [`./modules/flake`](./modules/flake) via
[`vic/import-tree`](https://github.com/vic/import-tree). Every `.nix` file
under `./modules/flake` is a flake-parts module that self-registers a piece of
the flake output: a reusable module, a host configuration, an overlay, a
devShell, etc. There is no central file that imports everything.

```
modules/flake/
├── imports.nix, systems.nix, options.nix    # flake-parts plumbing
├── nixpkgs.nix, overlays.nix, packages.nix  # per-system package wiring
├── devshell.nix, treefmt.nix, pre-commit.nix
├── hosts/      # one file per concrete config output
├── nixos/      # flake.nixosModules.<name>
├── darwin/     # flake.darwinModules.<name>
├── home/       # flake.homeModules.<name>
└── profiles/   # personal/work profiles, declared across all three classes
```

The module bodies (the actual NixOS / nix-darwin / home-manager logic) live at
their legacy locations under `./modules/{common,nixos,darwin,home-manager}/`
and `./profiles/`. Each wrapper in `./modules/flake/` is a three-line
flake-parts module that registers one of those bodies under its proper flake
output — for example, `modules/flake/nixos/hyprland.nix` is just
`flake.nixosModules.hyprland = ../../nixos/hyprland.nix`. This keeps module
implementation decoupled from flake plumbing.

### Overlapping nix-darwin and NixOS

nix-darwin and NixOS share as much overlap as possible in
[`./modules/common.nix`](./modules/common.nix) (primary-user plumbing, shells,
shared package set, fonts). Platform-specific modules add onto it in
[`./modules/nixos/default.nix`](./modules/nixos/default.nix) and
[`./modules/darwin/default.nix`](./modules/darwin/default.nix).

### Decoupled home-manager configuration

The home-manager configuration is entirely decoupled from NixOS and
nix-darwin. All modules live in
[`./modules/home-manager`](./modules/home-manager). For each host they are
pulled in via the flake-parts `hm` alias (see
[`./modules/primaryUser.nix`](./modules/primaryUser.nix)), which forwards
`config.hm.*` to `home-manager.users.${config.user.name}.*`. The same module
tree is also exposed as [`homeConfigurations`](./modules/flake/hosts/home-standalone.nix)
so it is fully usable as a standalone configuration on any Linux system via
the `home-manager` CLI.

### User profiles

User "profiles" live in [`./profiles`](./profiles); these modules configure
contextual, identity-specific settings such as SSL certificates or
work-vs-personal email addresses. Each profile is declared across all three
module classes in
[`./modules/flake/profiles`](./modules/flake/profiles).

## Installing a configuration

### Non-NixOS prerequisite: install the Nix package manager

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --determinate
```

Skip this step on NixOS, where `nix` is the package manager by default.

## System bootstrapping

### NixOS

Follow the installation instructions, then run:

```bash
sudo nixos-install --flake "github:kclejeune/system#phil"
```

Replace `phil` with `wally` or `gateway` for the other hosts.

### Darwin / Linux

Clone this repository into `~/.nixpkgs`:

```bash
git clone https://github.com/kclejeune/system ~/.nixpkgs
```

Bootstrap a new system by using `nh` to activate the config:

```bash
nix run .#nh -- darwin switch .#kclejeune@aarch64-darwin
```

`nh` auto-detects the host and installs nix-darwin or home-manager; override
with `--darwin` or `--home-manager` if needed.
