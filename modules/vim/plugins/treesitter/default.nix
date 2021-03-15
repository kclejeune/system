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
in {
  programs.neovim = {
    plugins = with pkgs.vimPlugins; [
      # new neovim stuff
      (pluginWithLua nvim-treesitter)
      (pluginWithLua nvim-treesitter-textobjects)
    ];
  };

  # Treesitter grammars
  # shamelessly stolen from @i077
  # https://github.com/i077/system/blob/master/modules/editors/neovim/default.nix
  # currently broken on macOS big sur
  # xdg.configFile = let
  #   # The languages for which I want to use tree-sitter
  #   languages = [
  #     "bash"
  #     "c"
  #     "cpp"
  #     "rust"
  #     "css"
  #     "go"
  #     "haskell"
  #     "html"
  #     "java"
  #     "javascript"
  #     "json"
  #     "lua"
  #     "nix"
  #     "python"
  #   ];
  #   # Map each language to its respective tree-sitter package
  #   grammarPkg = l:
  #     (pkgs.tree-sitter.builtGrammars.${"tree-sitter-" + l}.overrideAttrs
  #       (oldAttrs: rec {
  #         postPatch = ''
  #           for f in *.cc; do
  #             substituteInPlace $f --replace gcc cc
  #           done
  #         '';
  #       }));
  #   # Map each language to a name-value pair for xdg.configFile
  #   langToFile = lang:
  #     lib.nameValuePair "nvim/parser/${lang}.so" {
  #       source = "${grammarPkg lang}/parser";
  #     };
  #   # The final collection of name-value pairs
  #   files = map langToFile languages;
  # in builtins.listToAttrs files;
}
