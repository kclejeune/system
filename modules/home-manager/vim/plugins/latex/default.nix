{ config, pkgs, lib, ... }: {
  programs.neovim =
    let inherit (lib.vimUtils ./.) readLuaSection pluginWithLua;
    in
    {
      # vimtex config
      plugins = with pkgs.vimPlugins;
        [
          (pluginWithLua {
            plugin = vimtex;
            file = "vimtex";
          })
        ];

      # LSP config
      extraPackages = with pkgs; with nodePackages; [ texlab ];
    };
}
