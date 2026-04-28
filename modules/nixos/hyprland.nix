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

      # Force-stop fprintd before s2idle so its in-flight Verify session
      # (bound to the pre-suspend Goodix USB handle) is torn down cleanly.
      # Without this, the kernel re-enumerates the device on resume but
      # fprintd keeps the stale handle, and noctalia's next Claim returns
      # "Device was already claimed". fprintd is dbus-activated, so the
      # first call after resume auto-launches a fresh instance.
      systemd.services.fprintd.unitConfig = {
        Conflicts = [ "sleep.target" ];
        Before = [ "sleep.target" ];
      };

      services.upower.enable = true;
      services.power-profiles-daemon.enable = lib.mkDefault true;

      # Lid close → suspend; ignore lid close when docked (external
      # monitors). Power button → suspend. Noctalia's built-in
      # idle/lockOnSuspend is disabled in settings.json so hypridle
      # (configured in the home module) is the single coordinator for
      # both idle timeouts and logind PrepareForSleep hooks.
      services.logind.settings.Login = {
        HandleLidSwitch = "suspend";
        HandleLidSwitchDocked = "ignore";
        HandlePowerKey = "suspend";
      };

      hm.imports = [ flakeCfg.flake.homeModules.hyprland ];
    };
}
