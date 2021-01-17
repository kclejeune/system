{ config, pkgs, ... }: {
  imports = [ ../darwin-common.nix ../../../modules/users/work-settings.nix ];
}
