{ config, pkgs, lib, ... }: {
  programs.neovim =
    let inherit (lib.vimUtils ./.) pluginWithCfg;
    in
    {
      plugins = with pkgs.vimPlugins;
        [ (pluginWithCfg awesome-vim-colorschemes) ];
    };
}
