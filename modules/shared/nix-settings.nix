# Wires flake.lib.caches (nix-caches.nix) onto each platform's option
# surface. nixos uses plain nix.settings; darwin's base disables nix.enable
# and manages Nix via Determinate's determinateNix.customSettings instead —
# see modules/darwin/default.nix's comment on why nix.settings doesn't apply
# there.
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
