{ config, pkgs, ... }: {
  imports = [ ./vim ./zsh ./kitty ];
  # install extra common packages
  home.packages = with pkgs; [
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

  programs.fzf = {
    enable = true;
    defaultOptions = [ "--height 40%" "--border" ];
    changeDirWidgetCommand = "fd --type d";
    changeDirWidgetOptions = [ "--preview 'tree -C {} | head -200'" ];
    fileWidgetCommand = "fd --type f";
    fileWidgetOptions = [ "--preview 'bat --color=always --plain {}'" ];
  };

  programs.bat = {
    enable = true;
    config = { theme = "TwoDark"; };
  };

  programs.htop = { enable = true; };
}
