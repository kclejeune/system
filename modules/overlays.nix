{ inputs, config, lib, pkgs, nixpkgs, stable, ... }: {
  nixpkgs.overlays = [
    (final: prev:
      let
        # Import nixpkgs at a specified commit
        importNixpkgsRev = { rev, sha256 }:
          import
            (builtins.fetchTarball {
              name = "nixpkgs-src-" + rev;
              url = "https://github.com/NixOS/nixpkgs/archive/" + rev + ".tar.gz";
              inherit sha256;
            })
            {
              inherit (config.nixpkgs) config system;
              overlays = [ ];
            };
      in
      { })
    (final: prev: {
      # expose stable packages via pkgs.stable
      stable = import stable { system = prev.system; };
    })
    (final: prev: rec {
      kitty = pkgs.stable.kitty;
      # install comma from shopify repo
      comma = import inputs.comma rec {
        inherit pkgs;
      };
    })
  ];
}
