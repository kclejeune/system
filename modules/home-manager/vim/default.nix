{ config, pkgs, lib, ... }: {
  imports = [ ./plugins ];
  home.packages = [ pkgs.tree-sitter pkgs.luajit ];
  programs.neovim =
    let inherit (lib.vimUtils ./.) readVimSection;
    in
    {
      enable = true;
      package = pkgs.neovim-nightly;
      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;

      # nvim plugin providers
      withNodeJs = true;
      withRuby = true;
      withPython3 = true;

      # share vim plugins since nothing is specific to nvim
      plugins = with pkgs.vimPlugins; [
        # basics
        vim-sensible
        vim-fugitive
        vim-surround
        vim-commentary
        vim-sneak
        vim-closetag
        kotlin-vim

        # vim addon utilities
        direnv-vim
        ranger-vim
      ];
      extraConfig = ''
        ${readVimSection "settings"}
      '';
    };

}
