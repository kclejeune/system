# taken with heavy inspiration from https://github.com/Nimor111/nixos-config/

{ sources ? import ./nix/sources.nix }:
let
  pkgs = import sources.nixpkgs { };
  isDarwin = pkgs.stdenvNoCC.isDarwin;
  configuration = if isDarwin then
    ~/.nixpkgs/darwin-configuration.nix
  else
    /etc/nixos/configuration.nix;

  darwin-bootstrap = pkgs.writeShellScriptBin "darwin-bootstrap" ''
    set -e
    echo >&2
    echo >&2 "Installing Nix-Darwin..."
    echo >&2
    ${pkgs.lib.optionalString pkgs.stdenvNoCC.isDarwin ''
      cd /etc
      for file in bashrc shells skhdrc zprofile zshenv zshrc nix/nix.conf; do
          # if an /etc config file isn't a symlink, then we should move it
          [[ ! -L $file ]] && sudo mv $file "$file.bak" && echo "backed up $file"
      done

      # create the inital generation
      $(nix-build ${sources.nix-darwin} -A system --no-out-link)/sw/bin/darwin-rebuild switch --show-trace \
        -I nixpkgs=${sources.nixpkgs} \
        -I darwin=${sources.nix-darwin} \
        -I home-manager=${sources.home-manager} \
        -I darwin-config=${configuration} \
    ''}

    ${pkgs.lib.optionalString pkgs.stdenvNoCC.isDarwin darwinRebuild}
  '';

  darwinRebuild = pkgs.writeShellScriptBin "rebuild" ''
    set -e
    darwin-rebuild switch --show-trace \
      -I nixpkgs=${sources.nixpkgs} \
      -I darwin=${sources.nix-darwin} \
      -I home-manager=${sources.home-manager} \
      -I darwin-config=${configuration} \
  '';

  nixosRebuild = pkgs.writeShellScriptBin "rebuild" ''
    set -e
    sudo nixos-rebuild switch --show-trace \
      -I nixpkgs=${sources.nixpkgs} \
      -I home-manager=${sources.home-manager} \
      -I nixos-config=${configuration} \
  '';

  rebuild = if isDarwin then darwinRebuild else nixosRebuild;

in pkgs.mkShell { buildInputs = [ rebuild darwin-bootstrap ]; }
