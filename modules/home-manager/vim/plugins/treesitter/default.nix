{ config, pkgs, lib, ... }: {
  home.packages = [ pkgs.tree-sitter ];
  programs.neovim =
    let inherit (lib.vimUtils ./.) pluginWithLua;
    in
    {
      plugins = with pkgs.vimPlugins; [
        # new neovim stuff
        (pluginWithLua {
          plugin = nvim-treesitter;
          # (nvim-treesitter.withPlugins (_: pkgs.tree-sitter.allGrammars));
          file = "nvim-treesitter";
        })
        (pluginWithLua {
          plugin = nvim-treesitter-textobjects;
          file = "nvim-treesitter-textobjects";
        })
        completion-treesitter
      ];
    };
}
