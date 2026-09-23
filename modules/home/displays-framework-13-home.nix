_: {
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
      edp = position: {
        criteria = "eDP-1";
        mode = "preferred";
        scale = 2.0;
        inherit position;
      };
      u2718qLeft = {
        criteria = "Dell Inc. DELL U2718Q 4K8X779B03VL";
        mode = "3840x2160@60Hz";
        scale = 1.5;
        position = "0,0";
      };
      u2718qRight = {
        criteria = "Dell Inc. DELL U2718Q 4K8X77950L3L";
        mode = "3840x2160@60Hz";
        scale = 1.5;
        position = "2560,0";
      };
      u2718qAny = {
        criteria = "Dell Inc. DELL U2718Q *";
        mode = "3840x2160@60Hz";
        scale = 1.5;
        position = "0,0";
      };
      u3425we = {
        criteria = "Dell Inc. DELL U3425WE *";
        mode = "3440x1440@120Hz";
        scale = 1.25;
        position = "0,0";
      };
    in
    {
      wayland.windowManager.hyprland.settings = {
        monitor = lib.mkBefore [
          "eDP-1, preferred, 0x0, 2"
        ];

        workspace = [
          "name:B, monitor:desc:Dell Inc. DELL U2718Q 4K8X779B03VL, default:true"
          "name:V, monitor:desc:Dell Inc. DELL U2718Q 4K8X77950L3L"
          "name:I, monitor:desc:Dell Inc. DELL U2718Q 4K8X77950L3L"
        ];
      };

      services.kanshi.settings = [
        {
          # Logical width 5120; laptop centered below at (5120 - 1440) / 2.
          profile.name = "dual-4k";
          profile.outputs = [
            u2718qLeft
            u2718qRight
            (edp "1840,1440")
          ];
        }
        {
          profile.name = "dual-4k-clamshell";
          profile.outputs = [
            u2718qLeft
            u2718qRight
          ];
        }
        {
          # Logical width 2560; laptop centered below at (2560 - 1440) / 2.
          profile.name = "single-4k";
          profile.outputs = [
            u2718qAny
            (edp "560,1440")
          ];
        }
        {
          profile.name = "single-4k-clamshell";
          profile.outputs = [ u2718qAny ];
        }
        {
          # Logical width 2752; laptop centered below at (2752 - 1440) / 2.
          profile.name = "single-uwqhd";
          profile.outputs = [
            u3425we
            (edp "656,1152")
          ];
        }
        {
          profile.name = "single-uwqhd-clamshell";
          profile.outputs = [ u3425we ];
        }
        {
          profile.name = "undocked";
          profile.outputs = [
            {
              criteria = "eDP-1";
              mode = "preferred";
              scale = 2.0;
            }
          ];
        }
      ];
    };
}
