{
  config,
  pkgs,
  ...
}: {
  programs.neovim = {
    plugins = with pkgs.vimPlugins; [
      (config.lib.vimUtils.pluginWithCfg {
        plugin = guess-indent-nvim;
        file = ./guess-indent.lua;
      })
    ];
  };
}
