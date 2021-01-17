{ config, pkgs, ... }: {
  imports = [
    ../base.nix
    ../../../modules/users/work-settings.nix
  ];
}
