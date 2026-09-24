# Nix System Configuration

[![build](https://github.com/kclejeune/system/actions/workflows/build.yml/badge.svg)](https://github.com/kclejeune/system/actions/workflows/build.yml)

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
`pkgs/` (custom packages), and
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

NixOS hosts are provisioned remotely with
[nixos-anywhere](https://github.com/nix-community/nixos-anywhere), which
partitions the disk from the host's disko config, builds the system locally
and copies it over SSH.

1. **Pre-generate the host's SSH host key.** sops-nix decrypts secrets with
   it during `nixos-install`, and profile-personal's login password lives in
   `secrets/users.yaml` (`mutableUsers = false`, so there is no fallback).
   Without the key in place at install time the user ends up with no
   password.

   ```bash
   host=<hostname>
   keys=$(mktemp -d)
   install -d -m755 "$keys/etc/ssh"
   ssh-keygen -q -t ed25519 -N "" -C "root@$host" -f "$keys/etc/ssh/ssh_host_ed25519_key"
   ssh-to-age < "$keys/etc/ssh/ssh_host_ed25519_key.pub"
   ```

2. **Enroll the key in sops.** Add the printed age key as `&<hostname>` under
   `keys:` in `.sops.yaml`, reference it in every `creation_rules` entry the
   host needs (at minimum `secrets/users.yaml`), then re-encrypt:

   ```bash
   sops updatekeys secrets/users.yaml
   git add -A
   ```

3. **Boot the target into a NixOS installer ISO** (disable Secure Boot in
   firmware if it won't boot). The minimal ISO has no NetworkManager; join
   Wi-Fi with `sudo systemctl start wpa_supplicant` + `wpa_cli`. Set a
   password with `passwd`, note the IP, and from the provisioning machine:

   ```bash
   ssh-copy-id nixos@<ip>
   ```

   nixos-anywhere copies these `authorized_keys` to root and reconnects as
   root, so key auth is required — a password alone isn't enough.

4. **Install.** Run from an interactive terminal: disko prompts for the LUKS
   passphrase over the SSH tty.

   ```bash
   nix run github:nix-community/nixos-anywhere -- \
     --flake ".#$host" \
     --target-host nixos@<ip> \
     --extra-files "$keys"
   rm -rf "$keys"
   ```

   Add `--no-substitute-on-destination` if the target has LAN access to the
   provisioning machine but no internet uplink. The installer ISO is
   detected, so nothing is downloaded on the target. Check the install
   output for `setting up secrets for users...` with no `Cannot read ssh
key` / `failed to decrypt` errors after it.

5. **After first boot**, enroll a FIDO2 key for LUKS unlock:

   ```bash
   sudo systemd-cryptenroll --fido2-device=auto /dev/disk/by-partlabel/disk-main-luks
   ```

**Recovering a host that installed without its secrets** (e.g. no login
password): finish steps 1–2, boot the installer again, and rerun step 4 with
`--disko-mode mount --phases disko,install,reboot`. That unlocks and mounts
the existing disk instead of reformatting it (the log still prints
"Formatting hard drive with disko"; it only asks for the passphrase once),
places the host key and reinstalls.

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
