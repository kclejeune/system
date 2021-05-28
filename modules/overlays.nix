{ config, lib, pkgs, ... }: {
  nixpkgs.overlays = [
    # Overlay for temporary fixes to broken packages on nixos-unstable
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

        nixpkgs-63586 = importNixpkgsRev {
          rev = "63586475587d7e0e078291ad4b49b6f6a6885100";
          sha256 = "sha256:1323d6i478q9f2jbgijra7nhgkihyg7x4iyiirwjmxcr9wmzi7rs";
        };
      in
      { inherit (nixpkgs-63586) tree-sitter; })

    (final: prev: {
      # Patch ranger to run with PyPy instead of CPython.
      # This offers about a 2-3x speedup when working with directories with lots of entries,
      # e.g. the nix store.
      # stolen from @i077
      ranger = prev.ranger.overrideAttrs (oa: {
        postFixup = oa.postFixup + ''
          sed -i "s_#!/nix/store/.*_#!${pkgs.pypy3}/bin/pypy3_" $out/bin/.ranger-wrapped
        '';
      });
    })
  ];
}
