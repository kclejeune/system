# Shared shell / user / packages / home-manager wiring that applies equally
# to NixOS and nix-darwin. Registered under both flake.nixosModules.common-base
# and flake.darwinModules.common-base so each class's default module can
# import one name. Fonts live in `fonts.nix` so headless hosts skip them.
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
        description = "Kennan LeJeune";
        home = "${if pkgs.stdenvNoCC.isDarwin then "/Users" else "/home"}/${config.user.name}";
        shell = pkgs.zsh;
      };

      hm.imports = [ flakeCfg.flake.homeModules.default ];

      home-manager = {
        extraSpecialArgs = { inherit self inputs; };
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "backup";
      };

      environment = {
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
          nixpkgs.source = "${inputs.nixpkgs}";
        };
        shells = with pkgs; [
          bash
          zsh
          fish
        ];
      };

    };
}
