# Hyprland desktop session — tiling Wayland compositor.
# Imports desktop-base.nix for compositor-agnostic config.
# Coexists with gnome.nix — GDM shows both sessions at login.
{ pkgs, ... }:
{
  imports = [
    ./desktop-base.nix
  ];

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

  hm =
    { ... }:
    {
      imports = [
        ../home-manager/hyprland.nix
      ];
    };
}
