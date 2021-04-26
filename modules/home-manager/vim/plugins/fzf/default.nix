{ config, pkgs, lib, ... }:
let
  inherit (pkgs) fetchFromGitHub;
  inherit (pkgs.vimUtils) buildVimPluginFrom2Nix;

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
  programs.neovim =
    let
      nvim-fzf = buildVimPluginFrom2Nix {
        pname = "nvim-fzf";
        src = fetchFromGitHub {
          owner = "vijaymarupudi";
          repo = "nvim-fzf";
          rev = "b5e6feed6c14b7747fc66ab176c93ad8d578c9f0";
          sha256 = "sha256-dr3y93xA0QVxkhP8178UV3VmCMrb5BiyK98n684SxIw=";
        };
        version = "v0.1.0";
        meta.homepage = "https://github.com/vijaymarupudi/nvim-fzf";
      }; in
    {
      plugins = with pkgs.vimPlugins; [
        (pluginWithCfg fzf-vim)
        (pluginWithLua nvim-fzf)
      ];
      extraPackages = [ pkgs.fzf ];
    };
}
