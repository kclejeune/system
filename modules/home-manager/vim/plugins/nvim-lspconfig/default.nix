{ config, pkgs, lib, ... }: {
  programs.neovim =
    let inherit (lib.vimUtils ./.) pluginWithLua;
    in
    {
      # vimtex config
      plugins = with pkgs.vimPlugins;
        [
          # completion nvim
          (pluginWithLua {
            plugin = nvim-lspconfig;
            file = "nvim-lspconfig";
          })
        ];
    };
}
