{ config, pkgs, ... }: {
  dconf.settings = {

  };

  gtk = {
    enable = true;

    #     iconTheme = {
    #       package = pkgs.yaru;
    #       name = "yaru";
    #     };

    theme = {
      package = pkgs.gnome3.gnome_themes_standard;
      name = "Adwaita-dark";
    };

  };
  services.gnome-keyring.enable = true;
}
