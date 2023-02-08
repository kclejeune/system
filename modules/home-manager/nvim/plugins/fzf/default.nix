{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.neovim = {
    plugins = with pkgs.vimPlugins; [
      (config.lib.vimUtils.pluginWithCfg {
        plugin = fzf-vim;
        file = ./fzf-vim.lua;
      })
    ];
    extraPackages = [pkgs.fzf];
  };
}
