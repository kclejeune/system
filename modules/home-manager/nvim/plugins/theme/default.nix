{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (pkgs) vimUtils fetchFromGitHub;
in {
  programs.neovim = let
    auto-dark-mode-nvim = vimUtils.buildVimPlugin {
      pname = "auto-dark-mode.nvim";
      version = "v0.1.0";
      src = fetchFromGitHub {
        owner = "f-person";
        repo = "auto-dark-mode.nvim";
        rev = "c31de126963ffe9403901b4b0990dde0e6999cc6";
        sha256 = "sha256-ZCViqnA+VoEOG+Xr+aJNlfRKCjxJm5y78HRXax3o8UY=";
      };
      meta.homepage = "https://github.com/f-person/auto-dark-mode.nvim";
    };
  in {
    plugins = with pkgs.vimPlugins; [
      (config.lib.vimUtils.pluginWithCfg {
        plugin = awesome-vim-colorschemes;
        file = ./awesome-vim-colorschemes.lua;
      })
      (config.lib.vimUtils.pluginWithCfg {
        plugin = auto-dark-mode-nvim;
        file = ./auto-dark-mode.lua;
      })
    ];
  };
}
