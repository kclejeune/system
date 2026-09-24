_: {
  flake.homeModules.desktop-flag =
    { lib, ... }:
    {
      # Set by desktop-base and on darwin; headless hosts skip GUI config.
      options.desktop.enable = lib.mkEnableOption "desktop-mode home-manager";
    };
}
