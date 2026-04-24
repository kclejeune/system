{ config, ... }:
let
  flakeCfg = config;
in
{
  # GNOME desktop session — GDM + GNOME Shell. Assumes desktop-base is
  # enrolled separately (the `desktop` module does so).
  flake.nixosModules.gnome =
    { pkgs, ... }:
    {
      services.xserver.enable = true;
      services.xserver.xkb.layout = "us";
      services.desktopManager.gnome.enable = true;
      services.displayManager.gdm.enable = true;

      programs.gnupg.agent.pinentryPackage = pkgs.pinentry-gnome3;

      hm.imports = [ flakeCfg.flake.homeModules.gnome ];
    };
}
