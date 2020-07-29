# taken with heavy inspiration from https://github.com/Nimor111/nixos-config/

{ sources ? import ./nix/sources.nix }:
let

  pkgs = import sources.nixpkgs { };

  isDarwin = pkgs.stdenvNoCC.isDarwin;

  configuration = if isDarwin then
    ~/.config/nixpkgs/darwin/configuration.nix
  else
    /etc/nixos/configuration.nix;
  overlays =
    if isDarwin then ~/.config/nixpkgs/overlays else /etc/nixos/overlays;

  install = pkgs.writeShellScriptBin "install" ''
    set -e
    echo >&2
    echo >&2 "Installing..."
    echo >&2
    ${pkgs.lib.optionalString pkgs.stdenvNoCC.isDarwin ''
      echo "Setting up/tm nix-darwin..."
      cd /etc
      echo "Backing up /etc files"
      for file in bashrc shells skhdrc zprofile zshenv zshrc nix/nix.conf; do
          # if an /etc config file isn't a symlink, then we should move it
          [[ ! -L $file ]] && sudo mv $file "$file.bak" && echo "backed up $file"
      done

      cd ~
      if (! command -v darwin-rebuild); then
          echo >&2 "Installing nix-darwin..."
          mkdir -p ./nix-darwin && cd ./nix-darwin
          nix-build https://github.com/LnL7/nix-darwin/archive/master.tar.gz -A installer
          yes | ./result/bin/darwin-installer
          cd .. && rm -rf ./nix-darwin
      fi
    ''}

    ${pkgs.lib.optionalString pkgs.stdenvNoCC.isDarwin darwinRebuild}
  '';

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

in pkgs.mkShell { buildInputs = [ rebuild install ]; }

