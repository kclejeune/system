{ config, pkgs, lib, ... }: {
  imports = [ ./plugins ];
  programs.neovim =

    {
      enable = true;
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
        vim-sandwich
        vim-commentary
        vim-nix

        # vim addon utilities
        direnv-vim
        ranger-vim
      ];
      extraConfig = ''
        ${lib.vimUtils.readVimConfig ./settings.lua}
      '';
    };

}
