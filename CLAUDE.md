# Repository guide for Claude

Personal multi-host Nix/NixOS/nix-darwin/home-manager config built on the
**dendritic pattern** (flake-parts + `vic/import-tree`). Read this file
before making changes — the layout is intentional and has a few non-obvious
conventions.

## Top-level structure

- `flake.nix` — inputs, `nixConfig`, and a one-line `outputs` that hands
  everything under `./modules/flake` to `flake-parts.lib.mkFlake` via
  `import-tree`. Do **not** add logic here; add a new file under
  `./modules/flake/` instead.
- `modules/flake/` — the dendritic root. Every `.nix` file here is a
  flake-parts module. `import-tree` discovers them recursively, so new files
  are auto-registered.
- `modules/` (sibling to `flake/`) — the legacy module bodies. Regular
  NixOS / nix-darwin / home-manager modules. Wrappers in `modules/flake/`
  path-import these.
- `profiles/` — legacy per-identity modules (personal, work). Wrapped into
  `flake.{nixos,darwin,home}Modules.profile-{personal,work}` by
  `modules/flake/profiles/*.nix`.
- `pkgs/` — custom package definitions (cb, fnox, weave). Wired into
  `overlays.default` by `modules/flake/overlays.nix`.

## The wrapper pattern

Every reusable module under `modules/flake/{nixos,darwin,home}/<name>.nix` is
a three-line flake-parts module that registers a legacy body as a first-class
flake output. Example — `modules/flake/nixos/hyprland.nix`:

```nix
_: {
  flake.nixosModules.hyprland = ../../nixos/hyprland.nix;
}
```

That's the whole file. The actual Hyprland config is in
`modules/nixos/hyprland.nix` (a regular NixOS module). The wrapper
deliberately holds no logic — it only makes the legacy body visible to
flake-parts and any host that wants it.

This two-layer structure exists because the refactor kept ~5k lines of
working module code untouched. If you add a new feature, mirror the pattern:
write the body in the legacy location, add a wrapper.

## Adding a new reusable module

1. Write the module body at `modules/<class>/<name>.nix` as a normal module:
   ```nix
   { config, pkgs, ... }: { programs.foo.enable = true; }
   ```
2. Add a wrapper at `modules/flake/<class>/<name>.nix`:
   ```nix
   _: { flake.<class>Modules.<name> = ../../<class>/<name>.nix; }
   ```
   Where `<class>` is `nixos`, `darwin`, or `home`. (The `home` directory
   registers under `flake.homeModules`, matching flake-parts convention.)
3. Enroll it into whichever host needs it by adding a line in
   `modules/flake/hosts/<host>.nix`:
   ```nix
   modules = [ ... config.flake.nixosModules.<name> ... ];
   ```
   Or for home-manager features on nixos/darwin hosts, extend the host body's
   `hm.imports`.

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

- **`config.hm` shorthand**: `modules/primaryUser.nix` declares a `hm`
  option that `mkAliasDefinitions`-forwards to
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
  escape hatch for any `.nix` file under `./modules/flake` that should not
  register as a flake-parts module (none exist today, but it's available).
- **`flake.darwinModules` option** is declared in
  `modules/flake/options.nix` because upstream flake-parts does not declare
  it. Don't delete that file — without the declaration, multiple wrappers
  contributing to `darwinModules` collide on evaluation.

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
  pulled in via `hm.imports = [ ./home-manager ]` inside
  `modules/common.nix`. Headless hosts don't get home-manager by default;
  the `gateway` host works fine because common.nix's `hm.imports` only
  matters when `home-manager.users.<name>` is reachable. Do not replicate
  the `hm.imports` line in a new headless host.
- **`determinate` input**: provides `nixosModules.default` /
  `darwinModules.default` pulled in explicitly by each host file. It
  replaces the stock Nix package and manages its own substitute/trust
  config; don't also set `nix.settings.*` from elsewhere unless you know
  what you're doing.
