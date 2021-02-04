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
    kotlin-vim

    # vim addon utilities
    ranger-vim
    fzf-vim
    vim-nix

    # IDE-esque utilities
    coc-nvim
    vimtex
    coc-vimtex
    coc-css
    coc-html
    coc-eslint
    coc-tslint
    coc-json
    coc-prettier
    coc-tsserver
    coc-yaml
    coc-snippets
    coc-pairs
    coc-git
    coc-python
    coc-java

    # theming
    awesome-vim-colorschemes
  ];
in {
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
