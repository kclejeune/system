{ config, lib, pkgs, ... }: {
  user.name = "admin";
  hm = { imports = [ ./home-manager/personal.nix ]; };
}
