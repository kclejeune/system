{ config, ... }:
let
  flakeCfg = config;
in
{
  # Hyprland desktop session — tiling Wayland compositor. Assumes
  # desktop-base is enrolled separately (the `desktop` module does so).
  # Coexists with gnome — GDM shows both sessions at login.
  flake.nixosModules.hyprland =
    { pkgs, ... }:
    {
      programs.hyprland = {
        enable = true;
        xwayland.enable = true;
      };

      programs.hyprlock.enable = true;
      # Disable fprintd in PAM -- hyprlock handles fingerprint natively in
      # parallel with password (see auth block in HM hyprlock config)
      security.pam.services.hyprlock.fprintAuth = false;

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

      # GNOME Keyring for libsecret (used by Signal, Electron apps, etc.)
      services.gnome.gnome-keyring.enable = true;
      security.pam.services.hyprlock.enableGnomeKeyring = true;

      hm.imports = [ flakeCfg.flake.homeModules.hyprland ];
    };
}
