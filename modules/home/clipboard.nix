_: {
  # Also on headless hosts: wl-copy-over-SSH pipelines need the binaries.
  flake.homeModules.clipboard =
    { lib, pkgs, ... }:
    {
      home.packages = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
        with pkgs;
        [
          wl-clipboard-rs
          xclip
          xsel
        ]
      );
    };
}
