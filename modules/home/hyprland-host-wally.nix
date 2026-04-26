_: {
  # Wally-specific Hyprland overlay: built-in 1920x1200 OLED panel + the
  # two Dell U2718Q 4Ks at home + workspace pinning. Enrolled by
  # `hardware-precision-5570` so adding/removing a wally host swaps
  # everything in lockstep.
  flake.homeModules.hyprland-host-wally =
    { lib, ... }:
    {
      wayland.windowManager.hyprland.settings = {
        # Per-host monitor rules sort BEFORE the base catch-all so eDP-1
        # gets the right mode + scale on first frame and external rules
        # match before the unmatched-monitor fallback applies.
        monitor = lib.mkBefore [
          "eDP-1, 1920x1200@59.95Hz, 0x0, 1"
        ];

        workspace = [
          "name:B, monitor:desc:Dell Inc. DELL U2718Q 4K8X779B03VL, default:true"
          "name:V, monitor:desc:Dell Inc. DELL U2718Q 4K8X77950L3L"
          "name:I, monitor:desc:Dell Inc. DELL U2718Q 4K8X77950L3L"
        ];
      };

      # Kanshi profiles. Keep the eDP-1 entry's mode identical to the
      # static hyprland fallback above (59.95 Hz, scale 1.0) so wake
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
              scale = 1.0;
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
          profile.name = "undocked";
          profile.outputs = [
            {
              criteria = "eDP-1";
              mode = "1920x1200@59.95Hz";
              scale = 1.0;
            }
          ];
        }
      ];
    };
}
