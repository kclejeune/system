{ config, pkgs, ... }:
let
  readVimSection = file: builtins.readFile (./. + "/${file}.vim");
  vimPlugins = with pkgs.vimPlugins; [
    # basics
    vim-sensible
    vim-fugitive
    vim-surround
    vim-commentary
    vim-sneak
    vim-closetag
    vim-nix
    vim-polyglot

    # vim addon utilities
    ranger-vim
    fzf-vim
    vim-nix

    # IDE-esque utilities
    ale
    coc-nvim
    # coc-css
    # coc-html
    # coc-eslint
    # coc-prettier
    # coc-tslint
    # coc-tsserver
    # coc-python
    # coc-java

    # theming
    awesome-vim-colorschemes
  ];
in {
  programs.vim = {
    enable = false;
    plugins = vimPlugins;
    settings = {
      background = "dark";
      expandtab = true;
      tabstop = 4;
      shiftwidth = 4;
      smartcase = true;
      number = true;
      relativenumber = false;
      history = 10000;
    };
    extraConfig = ''
      ${readVimSection "settings"}
    '';
  };

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    # nvim plugin providers
    withNodeJs = true;
    withRuby = true;
    withPython = true;
    withPython3 = true;
    extraPython3Packages = (ps: with ps; [ black jedi pylint ]);

    # share vim plugins since nothing is specific to nvim
    plugins = vimPlugins;
    extraConfig = ''
      ${readVimSection "settings"}
    '';
  };
}
