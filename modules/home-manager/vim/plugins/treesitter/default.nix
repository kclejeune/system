{ config, pkgs, lib, ... }: {
  home.packages = [ pkgs.tree-sitter ];
  programs.neovim =
    let inherit (lib.vimUtils ./.) pluginWithLua;
    in
    {
      plugins = with pkgs.vimPlugins; [
        # new neovim stuff
        (pluginWithLua
          (nvim-treesitter.withPlugins (_: pkgs.tree-sitter.allGrammars)))
        (pluginWithLua nvim-treesitter-textobjects)
      ];
    };
}
