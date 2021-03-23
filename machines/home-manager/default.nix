{ inputs, config, pkgs, ... }: {
  imports =
    [ ../../modules/core.nix ../../modules/dotfiles ../../modules/home.nix ];
}
