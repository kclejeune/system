{
  pkgs,
  lib,
  ...
}:
{
  home.packages = lib.optionals (pkgs.stdenvNoCC.isDarwin) [
    pkgs.reattach-to-user-namespace
  ];
  programs.tmux = {
    enable = true;
    clock24 = true;
    historyLimit = 50000;
    escapeTime = 0;
    focusEvents = true;
    keyMode = "vi";
    terminal = "screen-256color";
    plugins = with pkgs.tmuxPlugins; [
      tmux-floax
      tmux-sessionx
      tmux-thumbs
      tmux-which-key
      sensible
    ];
    extraConfig = ''
      set -g allow-passthrough on
      set -ga update-environment TERM
      set -ga update-environment TERM_PROGRAM
      set -as terminal-features ",*-256color:RGB"
      bind -r k select-pane -U
      bind -r j select-pane -D
      bind -r h select-pane -L
      bind -r l select-pane -R
      bind g display-popup -E -xC -yC -w 80% -h 80% -d "#{pane_current_path}" ${pkgs.lazygit}/bin/lazygit
    ''
    + lib.optionalString pkgs.stdenvNoCC.isDarwin ''
      set -g default-command "${pkgs.reattach-to-user-namespace}/bin/reattach-to-user-namespace -l zsh"
    '';
  };
}
