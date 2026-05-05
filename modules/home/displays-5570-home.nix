_: {
  # Display layout for the precision-5570. Kanshi profiles are named by
  # topology rather than location:
  #
  #   dual-4k / dual-4k-clamshell           — two Dell U2718Q 4K panels
  #   single-uwqhd / single-uwqhd-clamshell — one Dell U3425WE 3440x1440
  #   undocked                              — laptop panel alone
  #
  # Single-external profiles use a model-scoped glob (trailing `*` on the
  # serial), matched via fnmatch(3) in kanshi (main.c:39). Dual profiles
  # use exact serials because kanshi rejects two `output` directives with
  # identical criteria strings in the same profile (config.c:354-362) —
  # even with globs, each entry in a profile must be unique.
  #
  # Shared by the personal `wally` host and the work
  # `klejeune@x86_64-linux` NixOS config, both of which pull this in
  # directly.
  flake.homeModules.displays-5570-home =
    { lib, ... }:
    {
      wayland.windowManager.hyprland.settings = {
        # Per-host monitor rules sort BEFORE the base catch-all so eDP-1
        # gets the right mode + scale on first frame and external rules
        # match before the unmatched-monitor fallback applies.
        monitor = lib.mkBefore [
          "eDP-1, 1920x1200@59.95Hz, 0x0, 1.25"
        ];

        workspace = [
          "name:B, monitor:desc:Dell Inc. DELL U2718Q 4K8X779B03VL, default:true"
          "name:V, monitor:desc:Dell Inc. DELL U2718Q 4K8X77950L3L"
          "name:I, monitor:desc:Dell Inc. DELL U2718Q 4K8X77950L3L"
        ];
      };

      # Kanshi profiles. Keep the eDP-1 entry's mode identical to the
      # static hyprland fallback above (59.95 Hz, scale 1.25) so wake
      # doesn't trigger a redundant modeset after kanshi fires.
      services.kanshi.settings = [
        {
          # Two Dell U2718Q 4K panels side-by-side with the laptop
          # centered below. Criteria use exact serials rather than a
          # shared `Dell Inc. DELL U2718Q *` glob because kanshi's
          # parser rejects two `output` directives with identical
          # criteria strings in the same profile (config.c:354-362 —
          # strcmp-based dedup, not fnmatch), so the two duals must be
          # distinguished. This also anchors each serial to a stable
          # left/right position, matching the hyprland workspace pins
          # on these serials in `workspace` above.
          profile.name = "dual-4k";
          profile.outputs = [
            {
              criteria = "Dell Inc. DELL U2718Q 4K8X779B03VL";
              mode = "3840x2160@60Hz";
              scale = 1.5;
              position = "0,0";
            }
            {
              criteria = "Dell Inc. DELL U2718Q 4K8X77950L3L";
              mode = "3840x2160@60Hz";
              scale = 1.5;
              position = "2560,0";
            }
            {
              criteria = "eDP-1";
              mode = "1920x1200@59.95Hz";
              scale = 1.25;
              position = "1600,1440";
            }
          ];
        }
        {
          profile.name = "dual-4k-clamshell";
          profile.outputs = [
            {
              criteria = "Dell Inc. DELL U2718Q 4K8X779B03VL";
              mode = "3840x2160@60Hz";
              scale = 1.5;
              position = "0,0";
            }
            {
              criteria = "Dell Inc. DELL U2718Q 4K8X77950L3L";
              mode = "3840x2160@60Hz";
              scale = 1.5;
              position = "2560,0";
            }
          ];
        }
        {
          # Single Dell U3425WE 3440x1440 ultrawide with the laptop
          # centered below. Scaled 1.25x, not 1.5x, since these displays
          # aren't 4K and 1.5 leaves non-integer logical dimensions on
          # 3440-wide panels. Logical size at 1.25 is 2752x1152; laptop
          # centered below at x = (2752 - 1920/1.25) / 2 = 608.
          profile.name = "single-uwqhd";
          profile.outputs = [
            {
              criteria = "Dell Inc. DELL U3425WE *";
              mode = "3440x1440@120Hz";
              scale = 1.25;
              position = "0,0";
            }
            {
              criteria = "eDP-1";
              mode = "1920x1200@59.95Hz";
              scale = 1.25;
              position = "608,1152";
            }
          ];
        }
        {
          profile.name = "single-uwqhd-clamshell";
          profile.outputs = [
            {
              criteria = "Dell Inc. DELL U3425WE *";
              mode = "3440x1440@120Hz";
              scale = 1.25;
              position = "0,0";
            }
          ];
        }
        {
          profile.name = "undocked";
          profile.outputs = [
            {
              criteria = "eDP-1";
              mode = "1920x1200@59.95Hz";
              scale = 1.25;
            }
          ];
        }
      ];
    };
}
