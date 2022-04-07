{ config, pkgs, lib, ... }: {
  programs.neovim = {
    plugins = with pkgs.vimPlugins;
      [
        (lib.vimUtils.pluginWithCfg {
          plugin = lualine-nvim;
          file = ./lualine-nvim.lua;
        })
      ];
  };
}
