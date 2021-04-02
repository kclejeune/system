{ config, pkgs, lib, ... }:
let
  readFile = file: ext: builtins.readFile (./. + "/${file}.${ext}");
  readVimSection = file: (readFile file "vim");
  readLuaSection = file: wrapLuaConfig (readFile file "lua");

  # For plugins configured with lua
  wrapLuaConfig = luaConfig: ''
    lua<<EOF
    ${luaConfig}
    EOF
  '';
  pluginWithLua = plugin: {
    inherit plugin;
    config = readLuaSection plugin.pname;
  };
  pluginWithCfg = plugin: {
    inherit plugin;
    config = readVimSection plugin.pname;
  };
in
{
  programs.neovim = {
    plugins = with pkgs.vimPlugins; [ vim-nix ];
    # LSP config
    extraPackages = with pkgs; with nodePackages; [ rnix-lsp ];
    extraConfig = ''
      ${readLuaSection "lsp"}
    '';
  };
}
