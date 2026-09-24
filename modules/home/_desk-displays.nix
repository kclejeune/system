# Home-desk monitors shared by the displays-*-home modules.
# kanshi applies the first profile whose outputs all match, so the serial-pinned
# dual-4k profiles precede the single-4k model glob. Dual profiles need exact
# serials: kanshi rejects duplicate criteria within one profile.
# The U3425WE uses 1.25x because 1.5 gives non-integer logical sizes at 3440 wide.
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
  workspaces = [
    "name:B, monitor:desc:Dell Inc. DELL U2718Q 4K8X779B03VL, default:true"
    "name:V, monitor:desc:Dell Inc. DELL U2718Q 4K8X77950L3L"
    "name:I, monitor:desc:Dell Inc. DELL U2718Q 4K8X77950L3L"
  ];

  # `edp` maps a position to the panel's output entry; `below` is where the panel
  # sits under each layout.
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
