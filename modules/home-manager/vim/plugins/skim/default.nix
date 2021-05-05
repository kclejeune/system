{ config, pkgs, lib, ... }: {
  programs.neovim = let inherit (lib.vimUtils ./.) pluginWithCfg;
  in {
    plugins = with pkgs.vimPlugins; [ skim (pluginWithCfg skim-vim) ];
    extraPackages = [ pkgs.skim ];
  };
}
