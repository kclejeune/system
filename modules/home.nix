{ inputs, config, pkgs, ... }:
let
  homeDir = config.home.homeDirectory;
  nixFlakes = "${pkgs.nixFlakes}/bin/nix";
  pyEnv = (pkgs.python3.withPackages
    (ps: with ps; [ black pylint typer colorama shellingham ]));
  sysDoNixos =
    "[[ -d /etc/nixos ]] && cd /etc/nixos && ${pyEnv}/bin/python do.py $@";
  sysDoDarwin =
    "[[ -d ${homeDir}/.nixpkgs ]] && cd ${homeDir}/.nixpkgs && ${pyEnv}/bin/python do.py $@";
  sysdo = (pkgs.writeShellScriptBin "sysdo" ''
    (${sysDoNixos}) || (${sysDoDarwin})
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
        (ps: with ps; [ bpython black pylint mypy numpy scipy networkx ]))

      # gnu stuff
      # encryption and signing utilities
      gnupg
      gawk
      gnused
      gnugrep

      # dev garbage
      nodejs
      yarn
      pre-commit
      jq
      kotlin

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
      texlive.combined.scheme-full
      tectonic
    ];
  };
}
