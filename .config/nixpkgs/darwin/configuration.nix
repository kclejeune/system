{ config, lib, pkgs, ... }:

let
  # generalize this for any user so that I can use it on a work machine
  defaultUser = (builtins.getEnv "USER");
  defaultHome = (builtins.getEnv "HOME");
  sources = import ../../nix/sources.nix;
  userShell = "zsh";
in {
  imports = [ ~/.config/nixpkgs/modules/darwin_modules ];

  users.users.${defaultUser} = {
    description = "Kennan LeJeune";
    home = defaultHome;
    shell = pkgs.${userShell};
    isHidden = false;
    createHome = false;
  };

  # bootstrap home manager from darwin rebuild
  home-manager.users.${defaultUser} = { pkgs, ... }: {
    imports = [ "${defaultHome}/.config/nixpkgs/home.nix" ];
  };

  # environment setup
  environment = {
    # Use a custom configuration.nix location.
    # $ darwin-rebuild switch -I darwin-config=$HOME/.config/nixpkgs/darwin/configuration.nix
    darwinConfig = ~/.config/nixpkgs/darwin/configuration.nix;
    systemPackages = with pkgs; [
      # editors
      vim
      neovim

      # standard toolset
      coreutils-full
      bat
      ripgrep
      zsh
      curl

      # scripting languages
      python3
      ruby

      jetbrains.idea-ultimate
    ];

    # list of acceptable shells in /etc/shells
    shells = with pkgs; [ bash zsh fish ];

    # packages installed in system profile
    # systemPackages = [ ];
    # change macOS login shell to nix provided zsh if it's set to something else
    extraInit = ''
      currentShell=$(finger ${defaultUser} | awk '/Shell/ {print $NF}')
      shellPath=/run/current-system/sw/bin/${userShell}
      if [[ $currentShell != $shellPath ]]; then
        chsh -s $shellPath ${defaultUser}
      fi
    '';
  };

  nix = {
    package = pkgs.nix;
    trustedUsers = [ defaultUser "root" "@admin" "@wheel" ];
    gc = {
      automatic = true;
      interval = {
        Hour = 3;
        Minute = 15;
      };
      options = "--delete-older-than 14d";
    };
    buildCores = 8;
    maxJobs = 8;
    readOnlyStore = true;
  };

  security.sandbox.profiles.${defaultUser}.allowSystemPaths = true;

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;

  # Create /etc/bashrc that loads the nix-darwin environment.
  programs.bash.enable = true;
  programs.zsh.enable = true;
  programs.fish.enable = true;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;
}
