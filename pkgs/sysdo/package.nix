{
  pkgs,
  lib,
  python3Packages,
  ...
}:
python3Packages.buildPythonPackage {
  pname = "sysdo";
  version = "0.1.0";
  pyproject = true;

  src = ./.;

  build-system = with python3Packages; [
    hatchling
  ];

  dependencies = with python3Packages; [
    colorama
    shellingham
    typer
  ];

  meta = with lib; {
    description = "A system configuration management CLI tool for NixOS, nix-darwin, and home-manager";
    homepage = "https://github.com/kclejeune/system";
    license = licenses.mit;
    maintainers = [];
    platforms = platforms.unix;
    mainProgram = "sysdo";
  };
}
