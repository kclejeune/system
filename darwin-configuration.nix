{ config, pkgs, ... }:

let
  # generalize this for any user so that I can use it on a work machine
  defaultUser = (builtins.getEnv "USER");
  defaultHome = (builtins.getEnv "HOME");
  prefix = "/run/current-system/sw/bin";
  userShell = "zsh";
  sources = import ./nix/sources.nix { };
in {
  imports =
    [ ./modules/darwin_modules ./modules/common.nix ];

  users.users.${defaultUser} = {
    description = "Kennan LeJeune";
    home = defaultHome;
    shell = pkgs.${userShell};
    isHidden = false;
    createHome = false;
  };

  # bootstrap home manager from darwin rebuild
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${defaultUser} = { pkgs, ... }: { imports = [ ./home.nix ]; };
  };

  # environment setup
  environment = {
    # Use a custom configuration.nix location.
    # $ darwin-rebuild switch -I darwin-config=$HOME/.config/nixpkgs/darwin/configuration.nix

    # packages installed in system profile
    # systemPackages = [ ];
    # change macOS login shell to nix provided zsh if it's set to something else
    # extraInit = ''
    #   currentShell=$(finger ${defaultUser} | awk '/Shell/ {print $NF}')
    #   shellPath=${prefix}/${userShell}
    #   if [[ $currentShell != $shellPath ]]; then
    #     chsh -s $shellPath ${defaultUser}
    #   fi
    # '';

    loginShell = pkgs.zsh;
    pathsToLink = [ "/Applications" ];
    shellAliases = {
      # rebuild = ''
      #   darwin-rebuild \
      #     -I nixpkgs=${sources.nixpkgs} \
      #     -I darwin=${sources.nix-darwin} \
      #     -I home-manager=${sources.home-manager} \
      #     -I darwin-config=${config.environment.darwinConfig} \
      # '';
      niv-system = ''
        niv -s ~/.nixpkgs/nix/sources.json
      '';
    };
    etc = {
      darwin = {
        source = "${sources.nix-darwin}";
        target = "sources/darwin";
      };
      home-manager = {
        source = "${sources.home-manager}";
        target = "sources/home-manager";
      };
      nixpkgs = {
        source = "${sources.nixpkgs}";
        target = "sources/nixpkgs";
      };
    };
  };

  nix.nixPath = [
    { darwin-config = "${config.environment.darwinConfig}"; }
    { darwin = "/etc/sources/darwin"; }
  ];

  # Overlay for temporary fixes to broken packages on nixos-unstable
  nixpkgs.overlays = [
    (self: super:
      let
        # Import nixpkgs at a specified commit
        importNixpkgsRev = { rev, sha256 }:
          import (builtins.fetchTarball {
            name = "nixpkgs-src-" + rev;
            url = "https://github.com/NixOS/nixpkgs/archive/" + rev + ".tar.gz";
            inherit sha256;
          }) {
            system = "x86_64-darwin";
            inherit (config.nixpkgs) config;
            overlays = [ ];
          };

        nixpkgs-b3c3a0b = importNixpkgsRev {
          rev = "f08a5cc832809dd28ac95be1cf94db19c8f53ba6";
          sha256 = "0qk61b86i3adz9xy188zrj6vrgg75ri7jjd0505nrxwknnd3nxdf";
        };
      in { inherit (nixpkgs-b3c3a0b) nixFlakes; })
  ];

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
