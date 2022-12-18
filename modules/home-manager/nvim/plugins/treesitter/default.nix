{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = [pkgs.tree-sitter];
  programs.neovim = {
    plugins = with pkgs.vimPlugins; [
      # new neovim stuff
      (config.lib.vimUtils.pluginWithCfg {
        plugin = nvim-treesitter.withAllGrammars;
        file = ./nvim-treesitter.lua;
      })
      (config.lib.vimUtils.pluginWithCfg {
        plugin = nvim-treesitter-textobjects;
        file = ./nvim-treesitter-textobjects.lua;
      })
    ];
  };
}
