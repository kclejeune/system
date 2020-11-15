{ inputs, config, pkgs, ... }:

let
  # generalize this for any user so that I can use it on a work machine
  prefix = "/run/current-system/sw/bin";
  defaultUser = "kclejeune";
  userShell = "zsh";
  sources = import ./nix/sources.nix { };
in {
  imports = [
    # <home-manager/nix-darwin>
    ./modules/darwin_modules
    ./modules/common.nix
    ./modules/personal-settings.nix
  ];

  users.users.${defaultUser} = {
    description = "Kennan LeJeune";
    home = "/Users/${defaultUser}";
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
    etc = {
      darwin = {
        source = "${inputs.darwin}";
        target = "sources/darwin";
      };
    };
  };

  nix.nixPath = [
    "darwin=/etc/${config.environment.etc.darwin.target}"
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

        nixpkgs-nixFlake = importNixpkgsRev {
          rev = "f08a5cc832809dd28ac95be1cf94db19c8f53ba6";
          sha256 = "0qk61b86i3adz9xy188zrj6vrgg75ri7jjd0505nrxwknnd3nxdf";
        };

        nixpkgs-stable = importNixpkgsRev {
          rev = "9be6b03fe1524db55a5277f87751cded5313b64b";
          sha256 = "0rz47yybzh9aihmyy1a82j5qbdc5k0a0l06ci3hm8fsva3cfz29r";
        };
      in {
        inherit (nixpkgs-nixFlake) nixFlakes;
        inherit (nixpkgs-stable) kitty ripgrep-all;
      })
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
