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
  imports = [ ./plugins ];
  home.packages = [ pkgs.tree-sitter pkgs.luajit ];
  programs.neovim = {
    enable = true;
    package = pkgs.neovim-nightly;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    # nvim plugin providers
    withNodeJs = true;
    withRuby = true;
    withPython = true;
    withPython3 = true;

    # share vim plugins since nothing is specific to nvim
    plugins = with pkgs.vimPlugins; [
      # basics
      vim-sensible
      vim-fugitive
      vim-surround
      vim-commentary
      vim-sneak
      vim-closetag
      vim-polyglot
      kotlin-vim
      nerdtree

      # vim addon utilities
      direnv-vim
      ranger-vim
    ];
    extraConfig = ''
      ${readVimSection "settings"}
    '';
  };

}
