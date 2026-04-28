{ config, ... }:
let
  flakeCfg = config;
in
{
  flake.nixosModules.hyprland =
    {
      lib,
      pkgs,
      ...
    }:
    {
      programs.hyprland = {
        enable = true;
        xwayland.enable = true;
      };

      services.xserver.enable = true;
      services.xserver.xkb.layout = "us";
      services.displayManager.gdm.enable = true;

      programs.gnupg.agent.pinentryPackage = pkgs.pinentry-gnome3;

      xdg.portal = {
        enable = true;
        extraPortals = [
          pkgs.xdg-desktop-portal-hyprland
          pkgs.xdg-desktop-portal-gtk
        ];
      };

      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        wireplumber.enable = true;
      };

      hardware.graphics.enable = true;

      security.polkit.enable = true;

      hardware.bluetooth.enable = true;

      services.gnome.gnome-keyring.enable = true;

      # Dedicated PAM service for noctalia's lock screen. Selected via the
      # `NOCTALIA_PAM_SERVICE` env var on the home side; without this,
      # noctalia falls back to /etc/pam.d/login, which has no fprintAuth
      # and so password is the only path. Mirrors the pattern hyprlock used.
      security.pam.services.noctalia = {
        fprintAuth = true;
        enableGnomeKeyring = true;
      };

      services.upower.enable = true;
      services.power-profiles-daemon.enable = lib.mkDefault true;

      # Lid close → suspend; ignore lid close when docked (external
      # monitors). Power button → suspend. Noctalia's built-in
      # idle/lockOnSuspend is disabled in settings.json so hypridle
      # (configured in the home module) is the single coordinator for
      # both idle timeouts and logind PrepareForSleep hooks.
      services.logind.lidSwitch = "suspend";
      services.logind.lidSwitchDocked = "ignore";
      services.logind.powerKey = "suspend";

      hm.imports = [ flakeCfg.flake.homeModules.hyprland ];
    };
}
