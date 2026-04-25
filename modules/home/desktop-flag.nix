_: {
  flake.homeModules.desktop-flag =
    { lib, ... }:
    {
      # Boolean signal for "this host has a graphical desktop". Set by
      # `nixosModules.desktop-base` (Linux GUI hosts) and `darwinModules.default`
      # (all darwin hosts), defaults to false elsewhere — so the headless
      # `gateway` evaluates with desktop.enable = false and skips kitty /
      # ghostty / vicinae / zed dotfiles and the heavy dev-interactive
      # package set.
      options.desktop.enable = lib.mkEnableOption "desktop-mode home-manager";
    };
}
