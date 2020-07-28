{ config, pkgs, ... }: {
  imports = [ ./vim ./zsh ./kitty ];
  # install extra common packages
  home.packages = with pkgs; [
    fzf
    bat
    fd
    ripgrep
    htop
    curl
    wget
    mosh
    openssh
    neofetch
    gawk
    mawk
    coreutils-full
  ];

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    enableFishIntegration = true;

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
