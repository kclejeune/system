{ config, pkgs, lib, ... }: {
  programs.neovim = let inherit (lib.vimUtils ./.) pluginWithLua;
  in { plugins = with pkgs.vimPlugins; [ (pluginWithLua nvim-autopairs) ]; };
}
