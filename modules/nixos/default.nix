{ config, ... }:
let
  flakeCfg = config;
in
{
  # NixOS base: shared shell/user/fonts from common, + NixOS-specific
  # settings (nix.settings trusted users, zsh default shell, locale,
  # gnupg, openssh). Pulls in primary-user + nixpkgs-wiring shared
  # modules, and enrolls the home-manager default module under the
  # primary user.
  flake.nixosModules.default =
    {
      self,
      inputs,
      config,
      pkgs,
      ...
    }:
    {
      imports = [
        flakeCfg.flake.nixosModules.primary-user
        flakeCfg.flake.nixosModules.nixpkgs-wiring
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

      # bootstrap home-manager using system config
      hm.imports = [ flakeCfg.flake.homeModules.default ];

      # let nix manage home-manager profiles and use global nixpkgs
      home-manager = {
        extraSpecialArgs = { inherit self inputs; };
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "backup";
      };

      environment = {
        systemPackages = with pkgs; [
          # editors
          neovim

          # standard toolset
          coreutils-full
          findutils
          diffutils
          curl
          wget
          git
          jq

          # helpful shell stuff
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

      # -- nixos-specific --
      nix.settings = {
        extra-trusted-users = [
          "${config.user.name}"
          "@wheel"
        ];
        keep-outputs = true;
        keep-derivations = true;
      };

      users.defaultUserShell = pkgs.zsh;

      i18n.defaultLocale = "en_US.UTF-8";

      programs.gnupg.agent = {
        enable = true;
        enableSSHSupport = true;
      };

      services.openssh.enable = true;
    };
}
