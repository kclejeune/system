{ config, pkgs, lib, ... }: {
  home.packages = [ pkgs.tree-sitter ];
  programs.neovim = {
    plugins = with pkgs.vimPlugins; [
      # new neovim stuff
      (config.lib.vimUtils.pluginWithCfg {
        plugin = (nvim-treesitter.withPlugins (_: pkgs.tree-sitter.allGrammars));
        file = ./nvim-treesitter.lua;
      })
      (config.lib.vimUtils.pluginWithCfg {
        plugin = nvim-treesitter-textobjects;
        file = ./nvim-treesitter-textobjects.lua;
      })
    ];
  };
}
