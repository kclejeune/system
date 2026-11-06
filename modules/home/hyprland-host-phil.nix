_: {
  # No external-monitor profile yet.
  flake.homeModules.hyprland-host-phil =
    { lib, ... }:
    {
      wayland.windowManager.hyprland.settings.monitor = lib.mkBefore [
        {
          output = "eDP-1";
          mode = "1920x1080@60Hz";
          position = "0x0";
          scale = 1.25;
        }
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
