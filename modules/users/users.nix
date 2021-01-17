# modules/users.nix -- Define user (and some base home-manager) configuration.

{ config, inputs, lib, ... }:

let inherit (lib.mine.files) mapFilesRecToList;
in {
  users.mutableUsers = false;

  user = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = [ "wheel" config.users.groups.keys.name ];
    name = "kclejeune";
    description = "Kennan LeJeune";
  };

  home-manager.useUserPackages = true;
  home-manager.useGlobalPkgs = true;
  hm.programs.home-manager.enable = true;
}
