{ config, pkgs, lib, ... }: {
  programs.neovim = let inherit (lib.vimUtils ./.) readLuaSection;
  in {
    plugins = with pkgs.vimPlugins; [ vim-nix ];
    # LSP config
    extraPackages = with pkgs; with nodePackages; [ rnix-lsp ];
    extraConfig = ''
      ${readLuaSection "lsp"}
    '';
  };
}
