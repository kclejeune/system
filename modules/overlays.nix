{ inputs, config, lib, pkgs, ... }: {
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
  ];
}
