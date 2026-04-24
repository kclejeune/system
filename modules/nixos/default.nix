{ config, ... }:
let
  flakeCfg = config;
in
{
  # NixOS base: imports the cross-class common-base (shell/user/fonts/env)
  # plus nixos-specific settings (trusted users, default shell, locale,
  # gnupg, openssh).
  flake.nixosModules.default =
    { config, pkgs, ... }:
    {
      imports = [
        flakeCfg.flake.nixosModules.common-base
        flakeCfg.flake.nixosModules.primary-user
        flakeCfg.flake.nixosModules.nixpkgs-wiring
      ];

      nix.settings = {
        extra-trusted-users = [
          "${config.user.name}"
          "@wheel"
        ];
        keep-outputs = true;
        keep-derivations = true;
      };

      users.defaultUserShell = pkgs.zsh;

      i18n.defaultLocale = "en_US.UTF-8";

      programs.gnupg.agent = {
        enable = true;
        enableSSHSupport = true;
      };

      services.openssh.enable = true;
    };
}
