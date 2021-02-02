{ config, pkgs, ... }: {
  imports = [ ./vim ./zsh ./kitty ./dotfiles ./git.nix ];

  # install extra common packages
  home.packages = with pkgs; [
    # add flake support to nix command
    (pkgs.symlinkJoin {
      name = "nix";
      paths = [ pkgs.nixFlakes ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/nix \
          --add-flags "--experimental-features \"nix-command flakes\""
      '';
    })
    cachix
    fd
    ripgrep
    htop
    curl
    wget
    mosh
    openssh
    neofetch
    gawk
    coreutils-full
  ];

  programs = {
    home-manager = {
      enable = true;
      path = "../machines/home.nix";
    };
    direnv = {
      enable = true;
      enableNixDirenvIntegration = true;
    };
    fzf = {
      enable = true;
      defaultOptions = [ "--height 40%" "--border" ];
      changeDirWidgetCommand = "fd --type d";
      changeDirWidgetOptions = [ "--preview 'tree -C {} | head -200'" ];
      fileWidgetCommand = "fd --type f";
      fileWidgetOptions = [ "--preview 'bat --color=always --plain {}'" ];
    };
    bat = {
      enable = true;
      config = { theme = "TwoDark"; };
    };
    jq.enable = true;
    htop.enable = true;
    gpg.enable = true;
    git = {
      enable = true;
      lfs.enable = true;
      aliases = {
        ignore =
          "!gi() { curl -sL https://www.toptal.com/developers/gitignore/api/$@ ;}; gi";
      };
    };
  };
}
