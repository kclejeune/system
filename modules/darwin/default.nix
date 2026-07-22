{ config, ... }:
let
  flakeCfg = config;
in
{
  # Darwin base: imports the cross-class common-base (shell/user/fonts/env)
  # plus darwin-specific settings (determinateNix, homebrew, 1password hm,
  # touch-id sudo, etc).
  flake.darwinModules.default =
    {
      inputs,
      config,
      pkgs,
      ...
    }:
    {
      imports = [
        flakeCfg.flake.darwinModules.common-base
        flakeCfg.flake.darwinModules.primary-user
        flakeCfg.flake.darwinModules.identity
        flakeCfg.flake.darwinModules.nixpkgs-wiring
        flakeCfg.flake.darwinModules.brew
        flakeCfg.flake.darwinModules.preferences
        # Every darwin host is GUI, so fonts go here. NixOS hosts get
        # them via desktop-base so headless `gateway` stays clean.
        flakeCfg.flake.darwinModules.fonts
        flakeCfg.flake.darwinModules.nix-caches
      ];

      hm.imports = [ flakeCfg.flake.homeModules.onepassword ];
      hm.desktop.enable = true;

      system.primaryUser = config.user.name;

      nix.enable = false;
      nix.package = pkgs.nix;
      determinateNix = {
        enable = true;
        customSettings = {
          extra-trusted-users = [
            "${config.user.name}"
            "@admin"
            "@root"
            "@sudo"
            "@wheel"
            "@staff"
          ];
          lazy-trees = true;
          keep-outputs = true;
          keep-derivations = true;
          extra-experimental-features = "external-builders nix-command flakes";
        };
        determinateNixd = {
          authentication.additionalNetrcSources = [ "/etc/nix/netrc" ];
          garbageCollector.strategy = "automatic";
          builder.state = "enabled";
        };
      };

      hm.nix.registry.darwin.flake = inputs.darwin;

      security.pam.services.sudo_local.touchIdAuth = true;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 5;
    };
}
