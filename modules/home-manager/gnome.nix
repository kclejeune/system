{
  lib,
  pkgs,
  ...
}: {
  targets.genericLinux.enable = pkgs.stdenvNoCC.isLinux;
  xdg.mime.enable = pkgs.stdenvNoCC.isLinux;

  gtk = lib.mkIf pkgs.stdenvNoCC.isLinux {
    enable = true;

    iconTheme = {
      package = pkgs.yaru-theme;
      name = "Yaru";
    };

    font = {
      package = pkgs.dejavu_fonts;
      name = "DejaVu Sans";
    };

    theme = {
      package = pkgs.yaru-theme;
      name = "Yaru-dark";
    };

    gtk3.extraConfig = {
      gtk-icon-theme-name = "Yaru";
      gtk-theme-name = "Yaru-dark";
      gtk-application-prefer-dark-theme = 1;
    };
  };

  dconf.settings = lib.mkIf pkgs.stdenvNoCC.isLinux {
    "org/gnome/desktop/datetime" = {automatic-timezone = true;};
    "org/gnome/desktop/peripherals/keyboard" = {
      delay = "uint32 304";
      repeat-interval = "uint32 13";
    };
    "org/gnome/desktop/peripherals/touchpad" = {
      two-finger-scrolling-enabled = true;
    };
    "org/gnome/desktop/wm/keybindings" = {close = ["<Alt>w"];};
  };
}
