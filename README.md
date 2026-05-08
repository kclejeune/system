# Nix System Configuration

[![Build Status](https://api.cirrus-ci.com/github/kclejeune/system.svg?branch=master)](https://cirrus-ci.com/github/kclejeune/system)

This repository manages system configurations for all of my macOS, NixOS, and
Linux machines.

## Structure

The flake follows the **dendritic pattern** on top of
[`flake-parts`](https://flake.parts). [`flake.nix`](./flake.nix) holds the
inputs, the concrete host outputs (`nixosConfigurations`,
`darwinConfigurations`, `homeConfigurations`), and the `perSystem` wiring
for overlays, devShell, treefmt, pre-commit, and checks.
[`vic/import-tree`](https://github.com/vic/import-tree) recursively pulls in
every `.nix` file under [`./modules`](./modules); each one self-registers as
a **reusable module body** (`flake.<class>Modules.<name>`). Hosts then
compose those modules by name.

```
modules/
├── _lib.nix   # mkAspect helper (underscore-prefixed, skipped by import-tree)
├── shared/    # cross-class option modules + wiring
│               (primary-user, common-base, nixpkgs-wiring, identity, fonts)
├── nixos/     # flake.nixosModules.<name>
├── darwin/    # flake.darwinModules.<name>
├── home/      # flake.homeModules.<name>  (includes assets/ for non-Nix files)
└── profiles/  # identity profiles registered across all three classes
```

Each module file inlines its body directly — a file like `modules/nixos/hyprland.nix`
both registers `flake.nixosModules.hyprland` and contains the full compositor
configuration. Cross-module references go through `config.flake.<class>Modules.<name>`
so `hm.imports = [ config.flake.homeModules.hyprland ]` in the NixOS module is
how the home-manager side of Hyprland is pulled in when Hyprland is enabled.

Non-Nix assets that aren't flake-parts modules live in `secrets/`,
`pkgs/{cb,fnox,weave}/` (custom package sources), and
`modules/home/assets/{dotfiles,nvim,yazi}/` (source-path references for
the corresponding home modules).

### Overlapping nix-darwin and NixOS

nix-darwin and NixOS share identical shell/user/fonts/packages setup via
[`modules/nixos/default.nix`](./modules/nixos/default.nix) and
[`modules/darwin/default.nix`](./modules/darwin/default.nix), with shared
option declarations (`user`, `hm`) and nixpkgs wiring factored into
[`modules/shared/`](./modules/shared).

### Decoupled home-manager configuration

The home-manager configuration is entirely decoupled from NixOS and
nix-darwin. All modules live in [`modules/home/`](./modules/home). For each
NixOS/darwin host they are pulled in via the flake-parts `hm` alias (see
[`modules/shared/primary-user.nix`](./modules/shared/primary-user.nix)),
which forwards `config.hm.*` to `home-manager.users.${config.user.name}.*`.
The same module tree is also exposed as `homeConfigurations` in
[`flake.nix`](./flake.nix) (fanned out across `x86_64-linux`,
`aarch64-linux`, and `aarch64-darwin`) so it is fully usable as a
standalone configuration on any Linux or macOS system via the
`home-manager` CLI.

### User profiles

User "profiles" live in [`modules/profiles`](./modules/profiles); these
modules configure contextual, identity-specific settings such as SSL
certificates or email addresses. Each profile is declared across all three
module classes in a single file via the `mkAspect` helper; currently only
`personal.nix` exists.

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
