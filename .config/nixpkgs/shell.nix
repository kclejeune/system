# taken with heavy inspiration from https://github.com/Nimor111/nixos-config/

{ sources ? import ./nix/sources.nix }:
let
  pkgs = import sources.nixpkgs { };

  isDarwin = pkgs.stdenvNoCC.isDarwin;

  niv = pkgs.symlinkJoin {
    name = "niv";
    paths = [ sources.niv ];
    buildInputs = [ pkgs.makeWrapper ];
    # postBuild = ''
    #   wrapProgram $out/bin/niv \
    #     --add-flags "--sources-file ${toString ./sources.json}"
    # '';
  };

  configuration = if isDarwin then
    ~/.config/nixpkgs/darwin/configuration.nix
  else
    /etc/nixos/configuration.nix;
  overlays =
    if isDarwin then ~/.config/nixpkgs/overlays else /etc/nixos/overlays;

  darwinRebuild = pkgs.writeShellScriptBin "rebuild" ''
    set -e
    darwin-rebuild switch --show-trace \
      -I darwin=${sources.nix-darwin} \
      -I nixpkgs=${sources.nixpkgs} \
      -I darwin-config=${configuration} \
  '';
  # -I nixpkgs-overlays=${overlays}

  nixosRebuild = pkgs.writeShellScriptBin "rebuild" ''
    set -e
    sudo nixos-rebuild switch --show-trace \
      -I nixpkgs=${sources.nixpkgs} \
      -I nixos-config=${configuration} \
  '';

  rebuild = if isDarwin then darwinRebuild else nixosRebuild;

in pkgs.mkShell { buildInputs = [ niv rebuild ]; }
