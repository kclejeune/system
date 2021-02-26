{ config, pkgs, ... }: {
  dconf.settings = {

  };

  gtk = {
    enable = true;

    iconTheme = {
      package = pkgs.yaru-theme;
      name = "yaru";
    };

    theme = {
      package = pkgs.yaru-theme;
      name = "yaru-dark";
    };

  };
  services.gnome-keyring.enable = true;
}
