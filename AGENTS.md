# Repository guide

Personal Nix config for NixOS, nix-darwin and home-manager, built on the
**dendritic pattern** (flake-parts + `vic/import-tree`). Read this before
changing anything: several conventions exist to avoid non-obvious failures.

## Layout

- `flake.nix` — inputs, `nixConfig`, every host, `perSystem` (overlay,
  devShell, treefmt, pre-commit, checks, apps). `nixConfig` must stay here:
  it's read before `mkFlake` runs.
- `modules/` — every `.nix` file is a flake-parts module auto-imported by
  `import-tree`. Files starting with `_` are skipped (`_lib.nix`,
  `home/_desk-displays.nix`) and imported explicitly.
  - `nixos/`, `darwin/`, `home/` — one file per reusable module, registered
    as `flake.<class>Modules.<name>` (`home/` → `flake.homeModules`).
  - `shared/` — cross-class options and wiring (`primary-user`, `common-base`,
    `nixpkgs-wiring`, `identity`, `site`, …).
  - `profiles/` — identity profiles declared for all classes via `mkAspect`.
  - `home/assets/` — non-Nix files (dotfiles, nvim, yazi) referenced by path.
- `pkgs/` — custom packages (`cb`, `sem-cli`, `tpm-keyring-unlock`,
  `traceway`), added to `overlays.default` in `flake.nix`.
- `secrets/` — sops-encrypted; recipients in `.sops.yaml`.
- `terraform/` + `modules/terranix.nix` — UniFi config via terranix
  (`nix run .#unifi`).

## Hosts

| Host                       | Role                                                | Builder                    |
| -------------------------- | --------------------------------------------------- | -------------------------- |
| phil, wally, stanley       | laptops (Hyprland)                                  | `mkDesktop`                |
| gateway                    | public Hetzner edge (Authelia, NetBird, monitoring) | `mkNixos`                  |
| haven, forge, vault, atlas | LAN homelab                                         | `mkHomelab`                |
| `kclejeune@aarch64-darwin` | macOS                                               | `darwinSystem`             |
| `kclejeune@<system>`       | standalone home-manager                             | `homeManagerConfiguration` |

`mkNixos` adds `host-baseline` (determinate, home-manager, disko, sops-nix)
and `nixosModules.default`; the others build on it. Module **order** inside
the builders is kept stable on purpose: reordering changes list-typed option
merges and therefore every drvPath.

## Module conventions

Every module registers itself and inlines its body:

```nix
{ config, ... }:
let
  flakeCfg = config; # flake-parts config; the inner `config` is the NixOS one
in
{
  flake.nixosModules.hyprland = { pkgs, ... }: {
    programs.hyprland.enable = true;
    hm.imports = [ flakeCfg.flake.homeModules.hyprland ];
  };
}
```

Use `_: { … }` when the module doesn't reference siblings. For a body shared
by several classes use `mkAspect` from `modules/_lib.nix` (`os` = same body
for nixos + darwin; `nixos`/`darwin`/`home` for class-specific bodies).

Enroll a module by adding it to the host's builder call in `flake.nix`, or,
for home-manager modules, to the relevant aggregator's `hm.imports`.

## Traps

- **Import each module exactly once per host.** flake-parts wraps every
  module reference with its own `_file`, so Nix can't dedupe them; a second
  import makes scalar options conflict. E.g. `desktop` imports
  `desktop-base`, so `hyprland` must not.
- **`hm` / `user` aliases** (`shared/primary-user.nix`) forward to
  `home-manager.users.<primary>` / `users.users.<primary>`.
- **Blast radius.** `gateway` and the homelab hosts enroll `profile-personal`
  and the full home-manager default, so anything added there ships to
  servers. Put GUI or personal-only apps in `personal-apps`, or gate them on
  `config.desktop.enable` in home modules.
- **Specialisations must tag themselves** or `nh` activates the default
  config instead of the running one. The value must equal the attr name:
  `environment.etc."specialisation".text = "<name>";` (NixOS) or
  `xdg.dataFile."home-manager/specialisation".text = "<name>";` (HM). This
  includes specialisations merged in from nixos-hardware.
- **Flakes only see tracked files.** `git add` new files before evaluating.
- **`determinate`** manages the Nix package and its trust settings; don't
  set `nix.settings.*` elsewhere without a reason.
- **`dotfiles.path`** (`home/dotfiles.nix`) hardcodes
  `~/.nixpkgs/modules/home/assets/dotfiles` for out-of-store symlinks; move
  it and the relative `./assets/...` paths together.
- **systemd-user env is stale after a switch** in a running session;
  `systemctl --user set-environment …` + restart the unit, or re-login.

## Deployment

- **Servers pull-deploy with comin** from the `deploy` branch, which
  `.github/workflows/promote.yml` fast-forwards to master only after every
  `build` job passes. comin verifies the tip commit's signature, so commits
  must be signed (your SSH key, or GitHub web-flow for UI merges), and it
  refuses heads that don't descend from what's running.
- Anything activated by hand on a server is reverted on the next poll. To
  trial a config, push to `testing-<hostname>` (branched from `deploy`).
- Pushing to master is effectively a deploy once CI is green.
- Laptops and darwin activate locally, always via `nh`:
  `nh os switch .#<host>`, `nh darwin switch '.#kclejeune@aarch64-darwin'`,
  `nh home switch '.#kclejeune@x86_64-linux'`. `NH_FLAKE` points here.
- `nix run .#deploy -- '.#<host>'` (deploy-rs) exists for bootstrapping and
  emergencies; sudo uses pam_rssh with the forwarded agent.
- New NixOS host: see README → System bootstrapping. The host key must be a
  sops recipient _before_ install, or the `users.yaml` password hash never
  lands and (with `mutableUsers = false`) the user has no password.

## Commands

```bash
nix develop                     # treefmt, prek, nh, gh, nurl, sops, ssh-to-age, nvd, …
nix fmt                         # nixfmt, statix, deadnix, shellcheck, actionlint, zizmor, …
nix run .#drvs > before.json    # drvPath of every host; diff before/after a refactor
nix build --no-link .#nixosConfigurations.<host>.config.system.build.toplevel
nix build --no-link .#checks.x86_64-linux.treefmt
```

Refactors should be drvPath-transparent: capture `nix run .#drvs` before and
after and diff. Evaluate hosts serially when memory is tight; parallel
full-flake evals can OOM.

## Updating `pkgs/`

1. Latest tag: `gh release view --repo <owner>/<repo> --json tagName -q .tagName`.
2. Source hash: `nurl https://github.com/<owner>/<repo> <tag>`
   (`nix-prefetch-url --unpack` gives the wrong hash for `fetchFromGitHub`).
3. Rust `cargoHash`: set a fake hash, `nix build .#<pkg>`, copy the `got:`.

Before adding a package here, check nixpkgs; drop local copies once upstream
catches up.
