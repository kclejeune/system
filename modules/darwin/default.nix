{ config, ... }:
let
  flakeCfg = config;
in
{
  # Darwin base: shared shell/user/fonts from common, + darwin-specific
  # settings (determinateNix, homebrew, 1password hm, touch-id sudo, etc).
  flake.darwinModules.default =
    {
      self,
      inputs,
      config,
      pkgs,
      ...
    }:
    {
      imports = [
        flakeCfg.flake.darwinModules.primary-user
        flakeCfg.flake.darwinModules.nixpkgs-wiring
        flakeCfg.flake.darwinModules.brew
        flakeCfg.flake.darwinModules.preferences
      ];

      # -- shared (from common.nix) --
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

      hm.imports = [
        flakeCfg.flake.homeModules.default
        flakeCfg.flake.homeModules.onepassword
      ];

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

      fonts.packages = with pkgs; [
        jetbrains-mono
        nerd-fonts.jetbrains-mono
      ];

      # -- darwin-specific --
      system.primaryUser = config.user.name;

      nix.enable = false;
      nix.package = pkgs.nix;
      determinateNix = {
        enable = true;
        customSettings = {
          extra-trusted-users = [
            "${config.user.name}"
            "@admin"
            "@root"
            "@sudo"
            "@wheel"
            "@staff"
          ];
          lazy-trees = false;
          keep-outputs = true;
          keep-derivations = true;
          extra-experimental-features = "external-builders nix-command flakes";
        };
        determinateNixd = {
          authentication.additionalNetrcSources = [ "/etc/nix/netrc" ];
          garbageCollector.strategy = "automatic";
          builder.state = "enabled";
        };
      };

      hm.home.sessionVariables.SDKROOT = "$(xcrun --show-sdk-path)";

      hm.home.sessionSearchVariables = {
        LIBRARY_PATH = [
          "${config.homebrew.prefix}/lib"
          "$SDKROOT/usr/lib"
          "/usr/local/lib"
          "/usr/lib"
        ];
        CPATH = [
          "${config.homebrew.prefix}/include"
          "$SDKROOT/usr/include"
          "/usr/local/include"
          "/usr/lib"
        ];
      };

      hm.nix.registry.darwin.flake = inputs.darwin;

      security.pam.services.sudo_local.touchIdAuth = true;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 5;
    };
}
