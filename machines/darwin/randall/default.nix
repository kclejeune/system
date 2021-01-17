{ config, pkgs, ... }: {
  imports = [ ../base.nix ../../../modules/users/personal-settings.nix ];
}
