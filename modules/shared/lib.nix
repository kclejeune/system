# Other flakes can't reach modules/_lib.nix by path, so expose it here.
_: {
  flake.lib.mkAspect = (import ../_lib.nix).mkAspect;
}
