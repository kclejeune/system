{...}: {
  imports = [
    ../common.nix
    ./core.nix
    ./brew.nix
    ./preferences.nix
    # ./display-manager.nix
  ];
}
