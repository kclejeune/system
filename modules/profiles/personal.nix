{ config, lib, pkgs, ... }: {
  user.name = "kclejeune";
  hm = { imports = [ ./home-manager/personal.nix ]; };
  homebrew.enable = true;
}
