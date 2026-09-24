_:
let
  desk = import ./_desk-displays.nix;
in
{
  flake.homeModules.displays-5570-home =
    { lib, ... }:
    let
      # Match the Hyprland fallback exactly so wake doesn't trigger a second modeset.
      panel = {
        criteria = "eDP-1";
        mode = "1920x1200@59.95Hz";
        scale = 1.25;
      };
    in
    {
      wayland.windowManager.hyprland.settings = {
        # mkBefore so eDP-1 gets its mode on the first frame, ahead of the catch-all.
        monitor = lib.mkBefore [
          "eDP-1, 1920x1200@59.95Hz, 0x0, 1.25"
        ];

        workspace = desk.workspaces;
      };

      services.kanshi.settings = desk.mkKanshiProfiles {
        edp = position: panel // { inherit position; };
        # Centered below: x = (external logical width - 1536) / 2.
        below = {
          dual4k = "1600,1440";
          single4k = "512,1440";
          uwqhd = "608,1152";
        };
        undocked = panel;
      };
    };
}
