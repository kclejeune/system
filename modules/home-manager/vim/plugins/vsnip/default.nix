{ config, pkgs, lib, ... }: {
  programs.neovim = {
    plugins = with pkgs.vimPlugins; [ vim-vsnip vim-vsnip-integ ];
    extraConfig = "";
  };
}
