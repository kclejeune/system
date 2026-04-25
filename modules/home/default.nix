{ config, ... }:
let
  flakeCfg = config;
in
{
  # Home-manager base: imports every reusable home module + the big
  # shared package set / program-enablement block.
  flake.homeModules.default =
    {
      inputs,
      config,
      pkgs,
      lib,
      ...
    }:
    {
      imports = [
        inputs.nix-index-database.homeModules.nix-index
        flakeCfg.flake.homeModules.bat
        flakeCfg.flake.homeModules.desktop-flag
        flakeCfg.flake.homeModules.dev
        flakeCfg.flake.homeModules.dev-interactive
        flakeCfg.flake.homeModules.direnv
        flakeCfg.flake.homeModules.dotfiles
        flakeCfg.flake.homeModules.fzf
        flakeCfg.flake.homeModules.git
        flakeCfg.flake.homeModules.nushell
        flakeCfg.flake.homeModules.nvim
        flakeCfg.flake.homeModules.shell
        flakeCfg.flake.homeModules.ssh
        flakeCfg.flake.homeModules.tldr
        flakeCfg.flake.homeModules.tmux
        flakeCfg.flake.homeModules.yazi
        flakeCfg.flake.homeModules.nixpkgs
      ];

      # Package lists live in `homeModules.dev` (always-on) and
      # `homeModules.dev-interactive` (desktop-only, gated on
      # `desktop.enable`). Imports above pull both in; only the
      # interactive set's body is no-op'd on headless hosts.
      home.stateVersion = "26.05";

      fonts.fontconfig.enable = true;

      programs = {
        home-manager.enable = true;
        difftastic.enable = true;
        difftastic.git.enable = true;
        dircolors.enable = true;
        eza = {
          enable = true;
          extraOptions = [
            "--group-directories-first"
            "--git"
          ];
        };
        fastfetch.enable = true;
        go.enable = true;
        gpg.enable = true;
        btop.enable = true;
        htop.enable = true;
        jq.enable = true;
        k9s = {
          enable = true;
          settings.refreshRate = 1;
        };
        lazygit = {
          enable = true;
          settings = {
            git.useExternalDiffGitConfig = true;
            git.overrideGpg = true;
          };
        };
        lazysql.enable = true;
        less.enable = true;
        man.enable = true;
        nix-your-shell = {
          enable = true;
          nix-output-monitor.enable = true;
        };
        nh = {
          enable = true;
          flake = lib.mkDefault "${config.home.homeDirectory}/.nixpkgs";
        };
        nix-index.enable = true;
        nix-index-database.comma.enable = true;
        pandoc.enable = true;
        ripgrep.enable = true;
        starship.enable = true;
        yt-dlp.enable = true;
        yt-dlp.package = pkgs.stable.yt-dlp;
      };
    };
}
