_: {
  # Wayland + X11 clipboard CLIs. Linux-only — macOS uses pbcopy/pbpaste.
  # Installed even on headless Linux hosts since OSC52-less editors (and
  # `wl-copy`-over-SSH pipelines) depend on having the binaries available.
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
