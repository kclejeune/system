lib: {
  vimUtils = rec {
    # For plugins configured with lua
    wrapLuaConfig = luaConfig: ''
      lua<<EOF
      ${luaConfig}
      EOF
    '';
    readVimConfig = file:
      if (lib.strings.hasSuffix ".lua" (builtins.toString file)) then
        wrapLuaConfig (builtins.readFile file) else
        builtins.readFile file;
    pluginWithCfg = { plugin, file }: {
      inherit plugin;
      config = readVimConfig file;
    };
  };
}
