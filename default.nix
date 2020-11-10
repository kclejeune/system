# taken with heavy inspiration from https://github.com/Nimor111/nixos-config/

{ sources ? import ./nix/sources.nix }:
let
  pkgs = import sources.nixpkgs { };
  isDarwin = pkgs.stdenvNoCC.isDarwin;
  configuration = if isDarwin then
    "$HOME/.nixpkgs/darwin-configuration.nix"
  else
    "/etc/nixos/configuration.nix";

  darwin-bootstrap = pkgs.writeShellScriptBin "darwin-bootstrap" ''
    set -e
    echo >&2
    echo >&2 "Installing Nix-Darwin..."
    echo >&2

    # setup nix-darwin global store
    sudo mkdir -p /run || sudo ln -s private/var/run /run

    # back up
    cd /etc
    for file in bashrc shells skhdrc zprofile zshenv zshrc nix/nix.conf; do
        # if an /etc config file isn't a symlink, then we should move it
        [[ -e $file ]] && [[ ! -L $file ]] && sudo mv $file "$file.bak" && echo "backed up $file"
    done

    echo darwin-config=${sources.nix-darwin}/modules/examples/simple.nix
    export NIX_PATH=darwin-config=${sources.nix-darwin}/modules/examples/simple.nix:darwin=${sources.nix-darwin}

    # build nix darwin
    nix-build ${sources.nix-darwin} -A system --no-out-link build

    export NIX_PATH=darwin-config=${configuration}:darwin=${sources.nix-darwin}

    # build the actual configuration once we do that
    sudo ./result/sw/bin/darwin-rebuild switch --flake ".#randall"
  '';

  darwinRebuild = pkgs.writeShellScriptBin "rebuild" ''
    set -e
    darwin-rebuild switch --flake ${configuration}
  '';

  nixosRebuild = pkgs.writeShellScriptBin "rebuild" ''
    set -e
    sudo nixos-rebuild switch --flake ${configuration}
  '';

  rebuild = if isDarwin then darwinRebuild else nixosRebuild;

in pkgs.mkShell {
  buildInputs = [
    # keep this line if you use bash
    pkgs.bashInteractive
    rebuild
    darwin-bootstrap
  ];
}

