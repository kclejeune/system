{ pkgs, ... }:
let darwin = import <darwin>;
in { imports = [ ./lorri.nix ./display-manager.nix ./preferences.nix ]; }
