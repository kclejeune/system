# Repository guide for Claude

Personal multi-host Nix/NixOS/nix-darwin/home-manager config built on the
**dendritic pattern** (flake-parts + `vic/import-tree`). Read this file
before making changes — the layout is intentional and has a few non-obvious
conventions.

## Top-level structure

- `flake.nix` — inputs, `nixConfig`, and a one-line `outputs` that hands
  everything under `./modules` to `flake-parts.lib.mkFlake` via
  `import-tree`. Do **not** add logic here; add a new file under `./modules/`
  instead.
- `modules/` — the dendritic root. Every `.nix` file here is a flake-parts
  module. `import-tree` discovers them recursively, so new files are
  auto-registered.
- `modules/{nixos,darwin,home}/` — reusable class-specific modules. Each
  file registers `flake.<class>Modules.<name>` with the full body inlined.
- `modules/shared/` — option modules and wiring shared across classes
  (`primary-user`, `nixpkgs-wiring`, `common-base`).
- `modules/_lib.nix` — `mkAspect` helper for declaring multi-class
  modules. Underscore-prefixed so `import-tree` skips it; imported
  explicitly via `import ../_lib.nix`.
- `modules/profiles/` — per-identity modules (personal, work) that declare
  `flake.{nixos,darwin,home}Modules.profile-<name>` in one file.
- `modules/hosts/` — one file per concrete top-level config
  (`flake.nixosConfigurations.<name>`, etc.).
- `modules/home-manager/{dotfiles,nvim,yazi}/` — **asset dirs only** (lua
  files, dotfiles, themes). Referenced from the corresponding `modules/home/*.nix`
  via relative paths. The `.nix` files are gone; only asset subdirs remain.
- `pkgs/` — custom package definitions (cb, fnox, weave). Wired into
  `overlays.default` by `modules/overlays.nix`.
- `secrets/` — sops-encrypted per-host secrets.

## The inlined-module pattern

Every reusable module lives in one file that both registers itself as a
flake-parts output AND contains the full body. Example —
`modules/nixos/hyprland.nix`:

```nix
{ config, ... }:
let
  flakeCfg = config;
in
{
  flake.nixosModules.hyprland =
    { pkgs, ... }:
    {
      programs.hyprland.enable = true;
      # … full body …
      hm.imports = [ flakeCfg.flake.homeModules.hyprland ];
    };
}
```

The outer `{ config, ... }` binding captures flake-parts' config (aliased as
`flakeCfg`) so the nixos module body — which would otherwise shadow `config`
with the NixOS config — can still reach sibling modules via
`flakeCfg.flake.<class>Modules.<name>`. This is the convention throughout.

Modules with no cross-class or sibling references skip the alias:

```nix
_: {
  flake.homeModules.bat = _: {
    programs.bat = { enable = true; config.theme = "TwoDark"; };
  };
}
```

## Multi-class modules: `mkAspect`

For a feature whose body applies to more than one class (e.g. registers
under both `nixosModules.X` and `darwinModules.X`, or adds a `homeModules`
companion), use the `mkAspect` helper in `modules/_lib.nix`. It collapses
the "define body once, register under N classes" pattern:

```nix
{ config, ... }:
let
  flakeCfg = config;
in
(import ../_lib.nix).mkAspect {
  name = "profile-personal";
  os = _: {
    # shared body for nixos + darwin
    user.name = "kclejeune";
    hm.imports = [ flakeCfg.flake.homeModules.profile-personal ];
  };
  home = _: {
    programs.git.settings.user.email = "kennan@case.edu";
  };
}
```

`os` is shorthand for "same body in `nixos` and `darwin`". Use
`nixos = …` / `darwin = …` explicitly when the class bodies diverge.
`home = …` registers under `flake.homeModules.<name>`. Any key you omit
doesn't register. See `modules/shared/common-base.nix`,
`modules/shared/primary-user.nix`, and
`modules/profiles/{personal,work}.nix` for live examples.

## Adding a new reusable module

1. Pick a class (`nixos`, `darwin`, `home`) and a short name.
2. Create `modules/<class>/<name>.nix`:
   ```nix
   _: {
     flake.<class>Modules.<name> = { config, pkgs, lib, ... }: {
       programs.foo.enable = true;
     };
   }
   ```
   (The `home` directory registers under `flake.homeModules`, matching
   flake-parts convention.)
3. If the body needs to reference sibling modules, switch to the closure
   form:
   ```nix
   { config, ... }:
   let flakeCfg = config; in {
     flake.<class>Modules.<name> = _: {
       imports = [ flakeCfg.flake.<class>Modules.<sibling> ];
     };
   }
   ```
4. Enroll in whichever host wants it by adding to `modules/hosts/<host>.nix`:
   ```nix
   modules = [ … config.flake.nixosModules.<name> … ];
   ```
   For home-manager features on a nixos/darwin host, add to the `hm.imports`
   list inside the relevant aggregator (e.g.
   `flake.nixosModules.default`'s `hm.imports`).

## Adding a new host

Create `modules/flake/hosts/<hostname>.nix` — one self-contained file that
calls `nixosSystem` / `darwinSystem` / `homeManagerConfiguration` and lists
the features to enable. See `phil.nix` / `wally.nix` / `gateway.nix` for
NixOS, `kclejeune-darwin.nix` for polymorphic darwin, and
`home-standalone.nix` for polymorphic standalone home.

**Output naming**: nixos host files expose `flake.nixosConfigurations.<bare-name>`
(e.g. `phil`, `wally`, `gateway` — not `user@system`). Darwin and standalone-home
still use the `user@system` form because they fan out across multiple systems.

## Key non-obvious conventions

- **`config.hm` shorthand**: `modules/shared/primary-user.nix` declares a
  `hm` option that `mkAliasDefinitions`-forwards to
  `home-manager.users.${config.user.name}`. So a nixos/darwin module can
  write `hm.programs.foo.enable = true;` and it will land on the primary
  user's home-manager config. There's a matching `user` option for
  `users.users.${config.user.name}`.
- **`specialArgs`**: every host passes `{ self, inputs, nixpkgs }` as
  `specialArgs` (or `extraSpecialArgs` for standalone home). The `nixpkgs`
  arg is the per-host nixpkgs (nixos uses `inputs.nixos-unstable`,
  darwin/standalone-home use `inputs.nixpkgs` which follows
  `nixpkgs-unstable`). Modules that need a stable channel use
  `pkgs.stable.<pkg>` via the overlay.
- **`nixConfig` stays in `flake.nix`**: it's evaluated pre-`mkFlake`, so it
  cannot move to a flake-parts module.
- **Underscore-prefixed files are excluded** from `import-tree`. Use this
  escape hatch for any `.nix` file under `./modules` that should not
  register as a flake-parts module.
- **`flake.darwinModules` option** is declared in
  `modules/options.nix` because upstream flake-parts does not declare it.
  Don't delete that file — without the declaration, files under
  `modules/darwin/` that each contribute a named module collide on
  evaluation.
- **Double-importing the same module is a trap.** Flake-parts wraps module
  values with unique `_file` annotations each time they're referenced, so
  Nix's identity-based import dedup DOES NOT work — two transitive
  references to `flakeCfg.flake.<class>Modules.foo` from different paths
  cause option conflicts for any scalar option `foo` sets. Structure
  imports so each reusable module is pulled in exactly once per host — e.g.
  `desktop` imports `desktop-base`, but `gnome` and `hyprland` do NOT (they
  assume `desktop` already enrolled it).

## Commands

- Dev shell (gets `treefmt`, `pre-commit`, `nh`, `fd`, `rg`, `uv`, etc.):
  ```bash
  nix develop
  ```
- Format every tracked file: `nix fmt` (runs `treefmt`).
- Build without activating:
  ```bash
  nix build .#nixosConfigurations.phil.config.system.build.toplevel
  nix build .#darwinConfigurations."kclejeune@aarch64-darwin".config.system.build.toplevel
  nix build .#homeConfigurations."kclejeune@x86_64-linux".activationPackage
  ```
- Activate (run on the target host):
  ```bash
  sudo nixos-rebuild switch --flake .#phil
  darwin-rebuild switch --flake .#kclejeune@aarch64-darwin
  home-manager switch --flake .#kclejeune@x86_64-linux
  ```
- Eval-only drvPath diff (useful for refactors — run before and after to
  prove a change is semantically transparent):
  ```bash
  nix eval --json --accept-flake-config \
    '.#nixosConfigurations.phil.config.system.build.toplevel.drvPath'
  ```
- Cross-eval a darwin config from a Linux box: add `--impure` and use
  `builtins.getFlake` so `pkgs` imports work without system-matching.

## Gotchas

- **`flake.nix` uncommitted changes** are not picked up until `git add`ed —
  nix flakes only see the git index. If you see `flake ... does not provide
  attribute ...` after creating new files, run `git add` and retry.
- **Dotfiles hardcoded path**: `modules/home-manager/dotfiles/default.nix`
  defines `config.dotfiles.path` defaulting to
  `${homeDirectory}/.nixpkgs/modules/home-manager/dotfiles`. If you ever
  move that directory, both the default and the `./asset` relative paths
  inside must be updated in lockstep.
- **Home-manager enrollment**: on nixos/darwin hosts, home-manager is
  pulled in via `hm.imports = [ flakeCfg.flake.homeModules.default ]`
  inside `modules/shared/common-base.nix`. Headless hosts like `gateway`
  still import common-base (via `nixos/default.nix`) but don't receive
  desktop-only HM modules because those are enrolled inside
  `nixos/desktop-base.nix`.
- **`host-baseline`** (`modules/nixos/host-baseline.nix`) bundles the
  third-party modules every NixOS host uses: `determinate`,
  `home-manager`, `disko`, `sops-nix`. Each host file imports
  `config.flake.nixosModules.host-baseline` instead of listing them
  individually. If you need to add another cross-host third-party
  module, add it there — not in the per-host file.
- **`determinate` input**: provides `nixosModules.default` /
  `darwinModules.default`. It replaces the stock Nix package and manages
  its own substitute/trust config; don't also set `nix.settings.*` from
  elsewhere unless you know what you're doing.
