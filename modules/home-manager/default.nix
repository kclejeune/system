{ config, pkgs, ... }: {
  imports = [ ./vim ./cli ./kitty ./dotfiles ./git.nix ];

  # install extra common packages
  home.packages = with pkgs; [ ];

  programs.home-manager = {
    enable = true;
    path = "${config.home.homeDirectory}/.nixpkgs/modules/home-manager";
  };
}
