{ config, pkgs, lib, ... }: {
  programs.neovim = {
    plugins = with pkgs.vimPlugins;
      [
        (lib.vimUtils.pluginWithCfg {
          plugin = awesome-vim-colorschemes;
          file = ./awesome-vim-colorschemes.lua;
        })
      ];
  };
}
