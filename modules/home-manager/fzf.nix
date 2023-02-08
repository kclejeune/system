{
  pkgs,
  lib,
  ...
}: let
  fd = lib.getExe pkgs.fd;
in {
  programs.fzf = rec {
    enable = true;
    defaultCommand = "${fd} -H --type f";
    defaultOptions = ["--height 50%"];
    fileWidgetCommand = "${defaultCommand}";
    fileWidgetOptions = [
      "--preview '${lib.getExe pkgs.bat} --color=always --plain --line-range=:200 {}'"
    ];
    changeDirWidgetCommand = "${fd} -H --type d";
    changeDirWidgetOptions = ["--preview '${pkgs.tree}/bin/tree -C {} | head -200'"];
    historyWidgetOptions = [];
  };
}
