_: {
  # Phil-specific Hyprland overlay: T460s 1920x1080 FHD panel, no
  # external-monitor profile yet. Enrolled by `hardware-thinkpad-t460s`.
  flake.homeModules.hyprland-host-phil =
    { lib, ... }:
    {
      wayland.windowManager.hyprland.settings.monitor = lib.mkBefore [
        "eDP-1, 1920x1080@60Hz, 0x0, 1.25"
      ];

      services.kanshi.settings = [
        {
          profile.name = "undocked";
          profile.outputs = [
            {
              criteria = "eDP-1";
              mode = "1920x1080@60Hz";
              scale = 1.25;
            }
          ];
        }
      ];
    };
}
