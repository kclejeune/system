# Fonts live in `fonts.nix` so headless hosts skip them.
{ config, ... }:
let
  flakeCfg = config;
in
(import ../_lib.nix).mkAspect {
  name = "common-base";
  os =
    {
      self,
      inputs,
      nixpkgs,
      config,
      pkgs,
      ...
    }:
    {
      programs.bash = {
        enable = true;
        completion.enable = true;
      };

      programs.zsh = {
        enable = true;
        enableCompletion = true;
        enableBashCompletion = true;
      };

      user = {
        home = "${if pkgs.stdenv.hostPlatform.isDarwin then "/Users" else "/home"}/${config.user.name}";
        shell = pkgs.zsh;
      };

      # On Darwin this filters the Nix-managed CA bundle, not the macOS Keychain.
      security.pki.caCertificateBlacklist = [
        "Comodo AAA Services root"
      ];

      hm.imports = [ flakeCfg.flake.homeModules.default ];

      home-manager = {
        extraSpecialArgs = { inherit self inputs nixpkgs; };
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "backup";
      };

      environment = {
        variables = {
          EDITOR = "nvim";
          VISUAL = "nvim";
        };
        systemPackages = with pkgs; [
          neovim
          coreutils-full
          findutils
          diffutils
          curl
          wget
          git
          jq
          bat
          fzf
          ripgrep
        ];
        etc = {
          home-manager.source = "${inputs.home-manager}";
          nixpkgs.source = "${nixpkgs}";
        };
        shells = with pkgs; [
          bash
          zsh
          fish
        ];
      };
    };
}
