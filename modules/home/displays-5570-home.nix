_: {
  # Display layout for the precision-5570 across home and single-external
  # docks: eDP-1 panel rule, monitor-pinned workspaces (home-only U2718Q
  # workspaces), and kanshi profiles. Home runs dual Dell U2718Q 4Ks
  # (`home`, `home-clamshell`); any other single-external setup (e.g. the
  # work Dell U3425WE ultrawide) uses the catch-all `single` /
  # `single-clamshell` profiles; `undocked` is the laptop alone. Shared by
  # the personal `wally` host and the work `klejeune@x86_64-linux` NixOS
  # config, both of which pull this in directly.
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
          profile.name = "home";
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
          profile.name = "home-clamshell";
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
          profile.name = "single";
          profile.outputs = [
            {
              # Catch-all for any single external monitor (currently the
              # work Dell U3425WE 3440x1440 ultrawide). Scaled 1.25x, not
              # 1.5x, since these displays aren't 4K and 1.5 leaves
              # non-integer logical dimensions on 3440-wide panels.
              # Logical size at 1.25 is 2752x1152; laptop centered below
              # at x = (2752 - 1920/1.25) / 2 = 608.
              #
              # `*` matches the first unmatched output. eDP-1 is pinned by
              # connector name below, so `*` resolves to the external. A
              # bare wildcard is required because kanshi criteria must be
              # an exact `make model serial` string (no partial globs).
              criteria = "*";
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
          profile.name = "single-clamshell";
          profile.outputs = [
            {
              criteria = "*";
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
