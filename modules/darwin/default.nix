{ pkgs, ... }: {
  imports = [ ./core.nix ./display-manager.nix ./preferences.nix ];
}
