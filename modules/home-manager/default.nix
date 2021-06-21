{ inputs, config, pkgs, ... }:
let
  homeDir = config.home.homeDirectory;
  pyEnv = (pkgs.python3.withPackages
    (ps: with ps; [ black pylint typer colorama shellingham ]));
  sysDoNixos =
    "[[ -d /etc/nixos ]] && cd /etc/nixos && ${pyEnv}/bin/python bin/do.py $@";
  sysDoDarwin =
    "[[ -d ${homeDir}/.nixpkgs ]] && cd ${homeDir}/.nixpkgs && ${pyEnv}/bin/python bin/do.py $@";
  sysdo = (pkgs.writeShellScriptBin "sysdo" ''
    (${sysDoNixos}) || (${sysDoDarwin})
  '');

in
{
  imports = [ ./vim ./cli ./kitty ./dotfiles ./git.nix ];

  programs.home-manager = {
    enable = true;
    path = "${config.home.homeDirectory}/.nixpkgs/modules/home-manager";
  };

  home =
    let
      java = pkgs.adoptopenjdk-bin;
    in
    {
      # This value determines the Home Manager release that your
      # configuration is compatible with. This helps avoid breakage
      # when a new Home Manager release introduces backwards
      # incompatible changes.
      #
      # You can update Home Manager without changing this value. See
      # the Home Manager release notes for a list of state version
      # changes in each release.
      stateVersion = "20.09";
      sessionVariables = {
        GPG_TTY = "/dev/ttys000";
        EDITOR = "nvim";
        VISUAL = "nvim";
        CLICOLOR = 1;
        LSCOLORS = "ExFxBxDxCxegedabagacad";
        KAGGLE_CONFIG_DIR = "${config.xdg.configHome}/kaggle";
        JAVA_HOME = "${java}";
      };

      # define package definitions for current user environment
      packages = with pkgs; [
        # python with default packages
        (python3.withPackages (ps: with ps; [ black numpy scipy networkx ]))
        cachix
        coreutils-full
        curl
        curlie
        fd
        gawk
        ghc
        git
        gnugrep
        gnupg
        gnused
        htop
        httpie
        hyperfine
        java
        jq
        kotlin
        neofetch
        niv
        nixUnstable
        nixfmt
        nixpkgs-fmt
        nodejs
        openssh
        pandoc
        pre-commit
        ranger
        ripgrep
        ripgrep-all
        rsync
        sysdo
        tealdeer
        tectonic
        # texlive.combined.scheme-full
        youtube-dl
      ];
    };
}
