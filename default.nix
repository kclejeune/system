{ pkgs ? import <nixpkgs> { } }:
let
  isDarwin = pkgs.stdenvNoCC.isDarwin;
  configuration = if isDarwin then
    "$HOME/.nixpkgs/darwin-configuration.nix"
  else
    "/etc/nixos/configuration.nix";

  systemSetup = ''
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
  '';

  darwinBuildScript = ''
    ${pkgs.nixFlakes}/bin/nix build ".#darwinConfigurations.$1.config.system.build.toplevel" -v --experimental-features "flakes nix-command" --show-trace
  '';

  darwinInstall = pkgs.writeShellScriptBin "darwinInstall" ''
    ${systemSetup}
    ${darwinBuildScript}
    sudo ./result/activate
  '';

  darwinBuild = pkgs.writeShellScriptBin "darwinBuild" ''
    ${darwinBuildScript}
  '';

  nixosBuild = ''
    ${pkgs.nixFlakes}/bin/nix build ".#nixosConfigurations.$1.config.system.build.toplevel" -v --experimental-features "flakes nix-command" --show-trace
  '';

  homebrewInstall = pkgs.writeShellScriptBin "homebrewInstall" ''
    ${pkgs.bash}/bin/bash -c "$(${pkgs.curl}/bin/curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
  '';

in pkgs.mkShell {
  buildInputs = [ pkgs.nixFlakes darwinBuild darwinInstall homebrewInstall ];
}

