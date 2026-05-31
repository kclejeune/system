_: {
  # nix-ld provides an ld.so stub + fallback library path so unpatched,
  # dynamically-linked binaries (language runtimes, vendored CLI tools,
  # downloaded release tarballs) run on NixOS without patchelf/FHS wrappers.
  #
  # This base set covers common CLI / runtime needs. Desktop hosts layer the
  # GUI libraries (gtk3, mesa, X11, …) on top in desktop-base.nix via an
  # additive `programs.nix-ld.libraries` assignment, so headless hosts that
  # only need to run the occasional vendored binary (e.g. gateway running the
  # netbird-idp-migrate release binary) don't pull the desktop GL/X stack into
  # their closure.
  flake.nixosModules.nix-ld =
    { pkgs, ... }:
    {
      programs.nix-ld.enable = true;
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
