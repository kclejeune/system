rec {
  # Common args for `import inputs.nixpkgs { … }` — used both by the
  # nixos/darwin `nixpkgs-wiring` module and by standalone home-manager
  # hosts that import their own pkgs. Centralizes allow-* flags and the
  # project overlay so they can't drift between the two.
  mkNixpkgsArgs = { self }: {
    config = {
      allowUnsupportedSystem = true;
      allowUnfree = true;
      allowBroken = false;
    };
    overlays = [ self.overlays.default ];
  };

  # Register a "feature" (aspect) under one or more flake.<class>Modules
  # attributes in a single call. Returns a flake-parts config fragment —
  # use it as the return value of a module file.
  #
  # Shape:
  #   mkAspect {
  #     name = "foo";
  #     os   = body;        # shorthand for both nixos + darwin
  #     nixos = body;       # class-specific override
  #     darwin = body;      # class-specific override
  #     home = body;        # home-manager class
  #   }
  #
  # `os` is the common case: one body that works in both nixos and darwin.
  # If both `os` and `nixos`/`darwin` are given, the class-specific one wins
  # for that class.
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
