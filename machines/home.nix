{ inputs, config, pkgs, ... }:
let
  homeDir = config.home.homeDirectory;
  nixFlakes = "${pkgs.nixFlakes}/bin/nix";
  sysDoNixos =
    "[[ -d /etc/nixos ]] && cd /etc/nixos && ${nixFlakes} develop -c /etc/nixos/do.py $@";
  sysDoDarwin =
    "[[ -d ${homeDir}/.nixpkgs ]] && cd ${homeDir}/.nixpkgs && ${nixFlakes} develop -c ${homeDir}/.nixpkgs/do.py $@";
  sysdo = (pkgs.writeShellScriptBin "sysdo" ''
    ${sysDoNixos} || ${sysDoDarwin}
  '');
in {
  imports = [ ../modules/core.nix ];

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home = {
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
      JAVA_HOME = "${pkgs.jdk11}";
    };

    # define package definitions for current user environment
    packages = with pkgs; [
      # nix stuff
      nixpkgs-fmt
      nixfmt
      niv
      sysdo

      # scripting
      (python3.withPackages
        (ps: with ps; [ bpython black numpy scipy pandas networkx click ]))

      # gnu stuff
      # encryption and signing utilities
      gnupg
      gawk
      gnused
      gnugrep

      # dev garbage
      nodejs
      pre-commit
      jq
      jdk11

      # command line utilities
      git
      curl
      wget
      ranger
      rsync
      httpie
      pandoc
      ripgrep
      ripgrep-all

      # other useful stuff
      youtube-dl
      speedtest-cli

      # typesetting
      # (texlive.combine { inherit (texlive) scheme-basic latexindent latexmk; })
      # texlive.combined.scheme-full
      tectonic
    ];
  };
}
