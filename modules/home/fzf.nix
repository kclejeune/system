_: {
  flake.homeModules.fzf =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      fd = lib.getExe pkgs.fd;
    in
    {
      programs.fzf = rec {
        enable = true;
        defaultCommand = "${fd} -H --type f";
        defaultOptions = [ "--height 50%" ];
        fileWidget.command = "${defaultCommand}";
        fileWidget.options = [
          "--preview '${lib.getExe pkgs.bat} --color=always --plain --line-range=:200 {}'"
        ];
        tmux.enableShellIntegration = true;
        changeDirWidget.command = "${fd} -H --type d";
        changeDirWidget.options = [ "--preview '${pkgs.tree}/bin/tree -C {} | head -200'" ];
        # atuin owns Ctrl-R; disable fzf's history widget binding when it's enabled.
        historyWidget.command = lib.mkIf config.programs.atuin.enable "";
      };
    };
}
