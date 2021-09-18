lib: basePath: rec {

  readFile = file: ext: builtins.readFile (basePath + "/${file}.${ext}");
  readVimSection = file: (readFile file "vim");
  readLuaSection = file: wrapLuaConfig (readFile file "lua");

  # For plugins configured with lua
  wrapLuaConfig = luaConfig: ''
    lua<<EOF
    ${luaConfig}
    EOF
  '';
  pluginWithLua = { plugin, file ? plugin.pname }: {
    inherit plugin;
    config = readLuaSection file;
  };
  pluginWithCfg = { plugin, file ? plugin.pname }: {
    inherit plugin;
    config = readVimSection file;
  };
}
