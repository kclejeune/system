# GNOME desktop session — GDM + GNOME Shell.
# Imports desktop-base.nix for compositor-agnostic config.
{ pkgs, ... }:
{
  imports = [
    ./desktop-base.nix
  ];

  services.xserver.enable = true;
  services.xserver.xkb.layout = "us";
  services.desktopManager.gnome.enable = true;
  services.displayManager.gdm.enable = true;

  programs.gnupg.agent.pinentryPackage = pkgs.pinentry-gnome3;

  hm =
    { ... }:
    {
      imports = [
        ../home-manager/gnome.nix
      ];
    };
}
