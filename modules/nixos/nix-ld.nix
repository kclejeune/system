_: {
  # CLI-only library set; desktop-base adds the GUI libs so headless hosts
  # don't pull the GL/X stack into their closure.
  flake.nixosModules.nix-ld =
    { pkgs, ... }:
    {
      programs.nix-ld.enable = true;
      # FHS shebangs for the same unpatched tools nix-ld exists for.
      services.envfs.enable = true;
      programs.nix-ld.libraries = with pkgs; [
        stdenv.cc.cc.lib
        zlib
        openssl
        icu
        curl
        glib
      ];
    };
}
