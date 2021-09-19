{ inputs, nixpkgs, stable, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      # expose stable packages via pkgs.stable
      stable = import stable { system = prev.system; };
    })
    (final: prev: rec {
      kitty = prev.stable.kitty;
      # install comma from shopify repo
      comma = import inputs.comma rec {
        pkgs = import nixpkgs {
          system = prev.system;
        };
      };
    })
  ];
}
