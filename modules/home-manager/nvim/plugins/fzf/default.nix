{ config, pkgs, lib, ... }:
let
  inherit (pkgs) fetchFromGitHub;
  inherit (pkgs.vimUtils) buildVimPluginFrom2Nix;
in
{
  programs.neovim = {
    plugins = with pkgs.vimPlugins;
      [
        (lib.vimUtils.pluginWithCfg {
          plugin = fzf-vim;
          file = ./fzf-vim.lua;
        })
      ];
    extraPackages = [ pkgs.fzf ];
  };
}
