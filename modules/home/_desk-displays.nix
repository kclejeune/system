# Home-desk monitors (two Dell U2718Q 4K, or one U3425WE ultrawide), shared
# by the per-laptop `displays-*-home` modules. Underscore-prefixed so
# import-tree skips it; those modules import it directly.
#
# Profile order matters: kanshi applies the first profile whose outputs all
# match, so the serial-pinned dual-4k profiles come before the model-glob
# single-4k fallback. See displays-5570-home.nix for the kanshi details.
let
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
  # Hyprland workspace pins on the two U2718Q serials.
  workspaces = [
    "name:B, monitor:desc:Dell Inc. DELL U2718Q 4K8X779B03VL, default:true"
    "name:V, monitor:desc:Dell Inc. DELL U2718Q 4K8X77950L3L"
    "name:I, monitor:desc:Dell Inc. DELL U2718Q 4K8X77950L3L"
  ];

  # `edp` maps a position string to the laptop panel's output entry;
  # `below` holds where the panel sits (centered below) for each layout;
  # `undocked` is the panel's standalone entry.
  mkKanshiProfiles =
    {
      edp,
      below,
      undocked,
    }:
    [
      {
        profile.name = "dual-4k";
        profile.outputs = [
          u2718qLeft
          u2718qRight
          (edp below.dual4k)
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
        profile.name = "single-4k";
        profile.outputs = [
          u2718qAny
          (edp below.single4k)
        ];
      }
      {
        profile.name = "single-4k-clamshell";
        profile.outputs = [ u2718qAny ];
      }
      {
        profile.name = "single-uwqhd";
        profile.outputs = [
          u3425we
          (edp below.uwqhd)
        ];
      }
      {
        profile.name = "single-uwqhd-clamshell";
        profile.outputs = [ u3425we ];
      }
      {
        profile.name = "undocked";
        profile.outputs = [ undocked ];
      }
    ];
}
