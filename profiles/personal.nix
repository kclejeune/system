{ config, lib, pkgs, ... }: {
  user.name = "kclejeune";
  homebrew.brewPrefix = "/opt/homebrew/bin";
  hm = { imports = [ ./home-manager/personal.nix ]; };
}
