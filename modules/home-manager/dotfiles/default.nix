{ config, pkgs, lib, ... }: {
  home.file = {
    keras = {
      source = ./keras;
      target = ".keras";
      recursive = true;
    };
    raycast = {
      source = ./raycast;
      target = ".local/bin/raycast";
      recursive = true;
    };
    zfunc = {
      source = ./zfunc;
      target = ".zfunc";
      recursive = true;
    };
    npmrc = {
      text = ''
        prefix = ${config.home.sessionVariables.NODE_PATH};
      '';
      target = ".npmrc";
    };
    zprofile = {
      target = ".zprofile";
      text = ''
        if [[ -d /etc/profile.d ]]; then
            for i in /etc/profile.d/*; do
              source $i
            done
        fi
      '';
    };
  };

  xdg.enable = true;
  xdg.configFile = {
    "nixpkgs/config.nix".source = ../../config.nix;
    karabiner = {
      source = ./karabiner;
      recursive = true;
    };
    kitty = {
      source = ./kitty;
      recursive = true;
    };
    skhd = {
      source = ./skhd;
      recursive = true;
    };
    yabai = {
      source = ./yabai;
      recursive = true;
    };
  };
}
