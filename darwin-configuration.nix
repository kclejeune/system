{ config, pkgs, ... }:

let
  # generalize this for any user so that I can use it on a work machine
  defaultUser = (builtins.getEnv "USER");
  defaultHome = (builtins.getEnv "HOME");
  prefix = "/run/current-system/sw/bin";
  userShell = "zsh";
in {
  imports =
    [ <home-manager/nix-darwin> ./modules/darwin_modules ./modules/common.nix ];

  users.users.${defaultUser} = {
    description = "Kennan LeJeune";
    home = defaultHome;
    shell = pkgs.${userShell};
    isHidden = false;
    createHome = false;
  };

  # bootstrap home manager from darwin rebuild
  home-manager.users.${defaultUser} = { pkgs, ... }: {
    imports = [ ./home.nix ];
  };

  # environment setup
  environment = {
    # Use a custom configuration.nix location.
    # $ darwin-rebuild switch -I darwin-config=$HOME/.config/nixpkgs/darwin/configuration.nix
    darwinConfig = ~/.nixpkgs/darwin-configuration.nix;

    # packages installed in system profile
    # systemPackages = [ ];
    # change macOS login shell to nix provided zsh if it's set to something else
    # extraInit = ''
    #   currentShell=$(finger ${defaultUser} | awk '/Shell/ {print $NF}')
    #   shellPath=
    #   if [[ $currentShell != $shellPath ]]; then
    #     chsh -s $shellPath ${defaultUser}
    #   fi
    # '';

    loginShell = "${prefix}/${userShell}";
    pathsToLink = [ "/Applications" ];
  };

  programs.zsh.enable = true;
  programs.fish.enable = true;
  programs.bash.enable = true;

  security.sandbox.profiles.${defaultUser}.allowSystemPaths = true;

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;
}
