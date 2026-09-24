_:
let
  desk = import ./_desk-displays.nix;
in
{
  # Display layout for the Framework 13 Pro — same home desk as
  # `displays-5570-home` (two Dell U2718Q 4K, or one U3425WE ultrawide),
  # but with the Framework's internal panel. See that module for why
  # profile order, exact-serial dual criteria and model globs are the
  # way they are.
  #
  # eDP-1 uses the panel's preferred mode at scale 2 and the positions
  # below assume a 1440px-wide logical panel (2880x1920 / 2). If the
  # panel's native width differs, recompute the centered-below x offsets
  # as (external logical width - eDP logical width) / 2.
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
        # Logical widths 5120 / 2560 / 2752; laptop centered below each.
        below = {
          dual4k = "1840,1440";
          single4k = "560,1440";
          uwqhd = "656,1152";
        };
        undocked = panel;
      };
    };
}
