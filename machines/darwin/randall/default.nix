{ config, pkgs, ... }: {
  imports =
    [ ../darwin-common.nix ../../../modules/users/personal-settings.nix ];
}
