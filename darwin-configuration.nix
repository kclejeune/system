{ inputs, config, pkgs, ... }:
let
  prefix = "/run/current-system/sw/bin";
in {
  imports = [
    ./modules/darwin_modules
    ./modules/common.nix
    ./modules/personal-settings.nix
  ];

  # environment setup
  environment = {
    loginShell = pkgs.zsh;
    pathsToLink = [ "/Applications" ];
    backupFileExtension = "backup";
    etc = {
      darwin = {
        source = "${inputs.darwin}";
        target = "sources/darwin";
      };
    };
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
  };

  nix.nixPath = [ "darwin=/etc/${config.environment.etc.darwin.target}" ];

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

        stable = import inputs.stable {
          system = "x86_64-darwin";
          inherit (config.nixpkgs) config;
          overlays = [ ];
        };
      in { })
  ];

  programs.zsh.enable = true;
  programs.fish.enable = true;
  programs.bash.enable = true;

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;
}
