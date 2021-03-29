{ inputs, config, pkgs, ... }: {
  imports =
    [ ../../modules/home-manager/core.nix ../../modules/home-manager/dotfiles ../../modules/home-manager/home.nix ];
}
