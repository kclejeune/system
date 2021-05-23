{ config, pkgs, lib, ... }: {
  programs.neovim =
    let inherit (lib.vimUtils ./.) readLuaSection;
    in
    {
      # LSP config
      extraPackages = with pkgs; with nodePackages; [ vue-language-server ];
      extraConfig = ''
        ${readLuaSection "lsp"}
      '';
    };
}
