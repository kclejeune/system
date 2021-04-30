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
    plugins = with pkgs.vimPlugins; [
      # new neovim stuff
      (pluginWithLua (nvim-treesitter.withPlugins (_: pkgs.tree-sitter.allGrammars)))
      (pluginWithLua nvim-treesitter-textobjects)
    ];
  };
}
