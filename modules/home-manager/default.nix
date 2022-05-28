{ inputs, config, pkgs, ... }:
let
  homeDir = config.home.homeDirectory;
  pyEnv =
    (pkgs.python3.withPackages (ps: with ps; [ typer colorama shellingham ]));
  sysDoNixos =
    "[[ -d /etc/nixos ]] && cd /etc/nixos && ${pyEnv}/bin/python bin/do.py $@";
  sysDoDarwin =
    "[[ -d ${homeDir}/.nixpkgs ]] && cd ${homeDir}/.nixpkgs && ${pyEnv}/bin/python bin/do.py $@";
  sysdo = (pkgs.writeShellScriptBin "sysdo" ''
    (${sysDoNixos}) || (${sysDoDarwin})
  '');

in
{
  imports = [
    ./nvim
    ./cli
    ./kitty
    ./dotfiles
    ./git.nix
    ./1password
  ];

  nixpkgs.config = {
    allowUnfree = true;
  };

  programs.home-manager = {
    enable = true;
    path = "${config.home.homeDirectory}/.nixpkgs/modules/home-manager";
  };

  home =
    let NODE_GLOBAL = "${config.home.homeDirectory}/.node-packages";
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
        JAVA_HOME = "${pkgs.openjdk11.home}";
        NODE_PATH = "${NODE_GLOBAL}/lib";
        # HOMEBREW_NO_AUTO_UPDATE = 1;
      };
      sessionPath = [
        "${NODE_GLOBAL}/bin"
        "${config.home.homeDirectory}/.rd/bin"
      ];

      # define package definitions for current user environment
      packages = with pkgs; [
        age
        # python with default packages
        (pkgs.python3.withPackages
          (ps: with ps; [ black numpy scipy networkx matplotlib ]))
        cachix
        comma
        curl
        fd
        ffmpeg
        gawk
        ghc
        git
        gnugrep
        gnupg
        gnused
        htop
        httpie
        jq
        luajit
        mmv
        neofetch
        nix
        nixfmt
        nixpkgs-fmt
        nodejs_latest
        openjdk11
        openssh
        pandoc
        parallel
        pkgs.coreutils-full
        poetry
        pre-commit
        ranger
        (pkgs.ruby.withPackages (ps: with ps; [ rufo solargraph ]))
        ripgrep
        rsync
        shellcheck
        stylua
        sysdo
        tealdeer
        terraform
        treefmt
        vagrant
        yarn
      ];
    };

}
