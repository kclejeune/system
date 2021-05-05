{ config, pkgs, lib, ... }: {
  programs.neovim =
    let inherit (lib.vimUtils) readLuaSection;
    in
    {
      # LSP config
      extraPackages = with pkgs;
        with nodePackages;
        [ vscode-css-languageserver-bin ];
      extraConfig = ''
        ${readLuaSection "lsp"}
      '';
    };
}
