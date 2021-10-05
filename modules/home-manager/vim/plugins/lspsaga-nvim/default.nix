{ config, pkgs, lib, ... }: {
  programs.neovim = let inherit (lib.vimUtils ./.) pluginWithLua;
  in {
    # vimtex config
    plugins = with pkgs.vimPlugins;
      [
        (pluginWithLua {
          plugin = lspsaga-nvim;
          file = "lspsaga-nvim";
        })
      ];
  };
}
