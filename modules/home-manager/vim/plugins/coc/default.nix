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
  # link coc-settings to the right location
  xdg.configFile."nvim/coc-settings.json".source = ./coc-settings.json;

  programs.neovim = {
    extraPackages = with pkgs; with nodePackages; [ rnix-lsp ];
    plugins = with pkgs.vimPlugins; [
      (pluginWithCfg coc-nvim)
      coc-css
      coc-eslint
      coc-fzf
      coc-git
      coc-go
      coc-html
      coc-json
      coc-lua
      coc-metals
      coc-pairs
      coc-prettier
      coc-pyright # python
      coc-r-lsp
      coc-rls
      coc-smartf
      coc-snippets
      coc-solargraph
      coc-tslint
      coc-tsserver # js/ts
      coc-vetur # vuejs
      coc-vimlsp # vimL
      coc-vimtex # latex
      coc-yaml
    ];
  };
}
