rec {
  # Shared by nixpkgs-wiring and flake.nix's own pkgs so they can't drift.
  mkNixpkgsArgs =
    { self }:
    {
      config = {
        allowUnsupportedSystem = true;
        allowUnfree = true;
        allowBroken = false;
      };
      overlays = [ self.overlays.default ];
    };

  # mkAspect { name; os ? body for nixos+darwin; nixos/darwin/home ? body; }
  # A class-specific body overrides `os` for that class.
  mkAspect =
    {
      name,
      os ? null,
      nixos ? null,
      darwin ? null,
      home ? null,
    }:
    let
      n = if nixos != null then nixos else os;
      d = if darwin != null then darwin else os;
    in
    {
      flake =
        (if n != null then { nixosModules.${name} = n; } else { })
        // (if d != null then { darwinModules.${name} = d; } else { })
        // (if home != null then { homeModules.${name} = home; } else { });
    };
}
