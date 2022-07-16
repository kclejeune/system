{ config, pkgs, lib, ... }:
let
  inherit (pkgs) fetchFromGitHub;
  inherit (pkgs.vimUtils) buildVimPluginFrom2Nix;
in
{
  programs.neovim = {
    plugins = with pkgs.vimPlugins; [
      (config.lib.vimUtils.pluginWithCfg {
        plugin = telescope-nvim;
        file = ./telescope-nvim.lua;
      })
      telescope-fzf-native-nvim
      plenary-nvim
    ];
    extraPackages = [ pkgs.ripgrep ];
  };
}
