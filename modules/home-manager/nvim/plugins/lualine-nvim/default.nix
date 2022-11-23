{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.neovim = {
    plugins = with pkgs.vimPlugins; [
      (config.lib.vimUtils.pluginWithCfg {
        plugin = lualine-nvim;
        file = ./lualine-nvim.lua;
      })
    ];
  };
}
