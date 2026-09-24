# darwin sets nix.enable = false (Determinate owns Nix there), so nix.settings
# doesn't apply; it goes through determinateNix.customSettings instead.
{ config, ... }:
let
  flakeCfg = config;
  inherit (flakeCfg.flake.lib.caches) substituters trustedPublicKeys;
in
(import ../_lib.nix).mkAspect {
  name = "nix-caches";
  nixos = _: {
    nix.settings = {
      extra-substituters = substituters;
      extra-trusted-public-keys = trustedPublicKeys;
    };
  };
  darwin = _: {
    determinateNix.customSettings = {
      extra-substituters = substituters;
      extra-trusted-public-keys = trustedPublicKeys;
    };
  };
}
