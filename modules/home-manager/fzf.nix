{ config, pkgs, lib, ... }: {
  programs.fzf = rec {
    enable = true;
    defaultCommand = "${pkgs.fd}/bin/fd --type f";
    defaultOptions = [ "--height 50%" ];
    fileWidgetCommand = "${defaultCommand}";
    fileWidgetOptions = [
      "--preview '${pkgs.bat}/bin/bat --color=always --plain --line-range=:200 {}'"
    ];
    changeDirWidgetCommand = "${pkgs.fd}/bin/fd --type d";
    changeDirWidgetOptions =
      [ "--preview '${pkgs.tree}/bin/tree -C {} | head -200'" ];
    historyWidgetOptions = [ ];
  };
}
