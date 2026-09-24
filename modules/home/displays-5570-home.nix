_:
let
  desk = import ./_desk-displays.nix;
in
{
  # Display layout for the precision-5570. Kanshi profiles are named by
  # topology rather than location:
  #
  #   dual-4k / dual-4k-clamshell           — two Dell U2718Q 4K panels
  #   single-4k / single-4k-clamshell       — one Dell U2718Q 4K panel
  #   single-uwqhd / single-uwqhd-clamshell — one Dell U3425WE 3440x1440
  #   undocked                              — laptop panel alone
  #
  # Single-external profiles use a model-scoped glob (trailing `*` on the
  # serial), matched via fnmatch(3) in kanshi (main.c:39). Dual profiles
  # use exact serials because kanshi rejects two `output` directives with
  # identical criteria strings in the same profile (config.c:354-362) —
  # even with globs, each entry in a profile must be unique. The exact
  # serials also anchor each panel to a stable left/right position,
  # matching the hyprland workspace pins.
  #
  # Profile ordering matters: kanshi applies the first profile whose
  # outputs all match (main.c:102-140). The dual-4k variants appear
  # before single-4k so that when both U2718Q serials are present the
  # dual layout wins; the single-4k wildcard only matches when the dual
  # serial-pinned profile cannot (e.g. dock MST partial failure).
  #
  # The U3425WE runs at 1.25x, not 1.5x: it isn't 4K, and 1.5 leaves
  # non-integer logical dimensions on 3440-wide panels.
  #
  # Enrolled by the `wally` host in flake.nix.
  flake.homeModules.displays-5570-home =
    { lib, ... }:
    let
      # Keep the eDP-1 mode identical to the static hyprland fallback below
      # (59.95 Hz, scale 1.25) so wake doesn't trigger a redundant modeset
      # after kanshi fires.
      panel = {
        criteria = "eDP-1";
        mode = "1920x1200@59.95Hz";
        scale = 1.25;
      };
    in
    {
      wayland.windowManager.hyprland.settings = {
        # Per-host monitor rules sort BEFORE the base catch-all so eDP-1
        # gets the right mode + scale on first frame and external rules
        # match before the unmatched-monitor fallback applies.
        monitor = lib.mkBefore [
          "eDP-1, 1920x1200@59.95Hz, 0x0, 1.25"
        ];

        workspace = desk.workspaces;
      };

      services.kanshi.settings = desk.mkKanshiProfiles {
        edp = position: panel // { inherit position; };
        # Logical widths: dual 5120, single-4k 2560 (so x = (2560 - 1536) / 2),
        # uwqhd 2752 at 1.25 (so x = (2752 - 1536) / 2).
        below = {
          dual4k = "1600,1440";
          single4k = "512,1440";
          uwqhd = "608,1152";
        };
        undocked = panel;
      };
    };
}
