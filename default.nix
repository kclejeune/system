# taken with heavy inspiration from https://github.com/Nimor111/nixos-config/

{ sources ? import ./nix/sources.nix }:
let
  pkgs = import sources.nixpkgs { };
  isDarwin = pkgs.stdenvNoCC.isDarwin;
  configuration = if isDarwin then
    "$HOME/.nixpkgs/darwin-configuration.nix"
  else
    "/etc/nixos/configuration.nix";

  darwinBuild = ''
    ${pkgs.nixFlakes}/bin/nix build ".#darwinConfigurations.Randall.config.system.build.toplevel" --experimental-features "flakes nix-command"
  '';
  darwinInstall = pkgs.writeShellScriptBin "darwinInstall" ''
    set -e
    echo >&2 "Installing Nix-Darwin..."

    # setup /run directory for darwin system installations
    if ! grep -q '^run\b' /etc/synthetic.conf 2>/dev/null; then
      echo "setting up /etc/synthetic.conf..."
      echo -e "run\tprivate/var/run" | sudo tee -a /etc/synthetic.conf >/dev/null
      /System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util -B 2>/dev/null || true
      /System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util -t 2>/dev/null || true
    fi
    if ! test -L /run; then
        echo "setting up /run..."
        sudo ln -sfn private/var/run /run
    fi

    # back up
    cd /etc
    for file in bashrc shells skhdrc zprofile zshenv zshrc nix/nix.conf; do
        # if an /etc config file isn't a symlink, then we should move it
        [[ -e $file ]] && [[ ! -L $file ]] && sudo mv $file "$file.backup" && echo "backed up $file"
    done

    ${darwinBuild} $$ ./result/activate
  '';

  darwinTest = pkgs.writeShellScriptBin "darwinTest" ''
    ${darwinBuild}
  '';

  homebrewInstall = pkgs.writeShellScriptBin "homebrewInstall" ''
    ${pkgs.bash}/bin/bash -c "$(${pkgs.curl}/bin/curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
  '';

in pkgs.mkShell { buildInputs = [ darwinTest darwinInstall homebrewInstall ]; }

