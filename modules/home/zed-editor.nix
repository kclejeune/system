_: {
  # Linux-only: Zed preview build from the upstream flake input (see
  # `modules/overlays.nix`). macOS gets Zed via Homebrew cask in
  # `modules/darwin/brew.nix` ("zed@preview"), so this module no-ops
  # there. Gated on `desktop.enable` so headless Linux hosts skip it.
  flake.homeModules.zed-editor =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      config = lib.mkIf (config.desktop.enable && pkgs.stdenvNoCC.isLinux) {
        programs.zed-editor = {
          enable = true;
          package = pkgs.zed-preview;
        };
      };
    };
}
