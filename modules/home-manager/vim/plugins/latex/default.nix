{ config, pkgs, lib, ... }: {
  programs.neovim = let inherit (lib.vimUtils ./.) readLuaSection pluginWithCfg;
  in {
    # vimtex config
    plugins = with pkgs.vimPlugins;
      [
        (pluginWithCfg {
          plugin = vimtex;
          file = "vimtex";
        })
      ];

    # LSP config
    extraPackages = with pkgs; with nodePackages; [ texlab ];
    extraConfig = ''
      ${readLuaSection "lsp"}
    '';
  };
}
