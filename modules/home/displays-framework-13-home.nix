_:
let
  desk = import ./_desk-displays.nix;
in
{
  # The `below` offsets assume a 1440px logical panel (2880x1920 at 2x).
  flake.homeModules.displays-framework-13-home =
    { lib, ... }:
    let
      panel = {
        criteria = "eDP-1";
        mode = "preferred";
        scale = 2.0;
      };
    in
    {
      wayland.windowManager.hyprland.settings = {
        monitor = lib.mkBefore [
          "eDP-1, preferred, 0x0, 2"
        ];

        workspace = desk.workspaces;
      };

      services.kanshi.settings = desk.mkKanshiProfiles {
        edp = position: panel // { inherit position; };
        # Centered below: x = (external logical width - 1440) / 2.
        below = {
          dual4k = "1840,1440";
          single4k = "560,1440";
          uwqhd = "656,1152";
        };
        undocked = panel;
      };
    };
}
