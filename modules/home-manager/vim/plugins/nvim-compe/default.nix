{ config, pkgs, lib, ... }: {
  programs.neovim =
    let inherit (lib.vimUtils ./.) readLuaSection pluginWithLua;
    in
    {
      plugins = with pkgs.vimPlugins; [
        (pluginWithLua {
          plugin = nvim-compe;
          file = "nvim-compe";
        })
        vim-vsnip
        vim-vsnip-integ
      ];
      extraConfig = ''
        ${readLuaSection "mappings"}
      '';
    };
}
