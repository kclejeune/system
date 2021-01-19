{ inputs, config, pkgs, ... }: {
  imports = [ ../../modules/core.nix ../../modules/dotfiles ../home.nix ];
}
