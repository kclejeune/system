{ pkgs ? import <nixpkgs> { } }:
let
  buildScriptFlags = ''
    -v --experimental-features "flakes nix-command" --show-trace
  '';

  darwinBuild = pkgs.writeShellScriptBin "darwinBuild" ''
    ${pkgs.nixFlakes}/bin/nix build ".#darwinConfigurations.$1.config.system.build.toplevel" ${buildScriptFlags}
  '';

  nixosBuild = pkgs.writeShellScriptBin "nixosBuild" ''
    ${pkgs.nixFlakes}/bin/nix build ".#nixosConfigurations.$1.config.system.build.toplevel" ${buildScriptFlags}
  '';

  homeManagerBuild = pkgs.writeShellScriptBin "homeManagerBuild" ''
    ${pkgs.nixFlakes}/bin/nix build ".#homeManagerConfigurations.$1.activationPackage" ${buildScriptFlags}
  '';

in pkgs.mkShell {
  buildInputs = with pkgs; [
    pkgs.nixFlakes
    pkgs.rnix-lsp
    (pkgs.python3.withPackages
      (ps: with ps; [ black pylint typer colorama shellingham distro ]))
    darwinBuild
    nixosBuild
    homeManagerBuild
  ];
}

