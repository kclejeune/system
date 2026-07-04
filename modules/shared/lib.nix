# Re-export the internal `mkAspect` helper through `flake.lib` so downstream
# flakes that import this one (via `inputs.<this>.lib.mkAspect`) can register a
# single body under both `flake.nixosModules.<name>` and
# `flake.darwinModules.<name>` the same way this repo does internally.
#
# `mkAspect` itself lives in modules/_lib.nix and is consumed here via a
# repo-relative import; that path isn't reachable from other flakes, so the
# `flake.lib` surface is the supported entry point for external consumers.
# Mirrors the `flake.lib.mkTheme` pattern in modules/shared/theme.nix.
_: {
  flake.lib.mkAspect = (import ../_lib.nix).mkAspect;
}
