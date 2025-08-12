{
  description = "nix system configurations";

  nixConfig = {
    extra-substituters = ["https://kclejeune.cachix.org"];
    extra-trusted-public-keys = ["kclejeune.cachix.org-1:fOCrECygdFZKbMxHClhiTS6oowOkJ/I/dh9q9b1I4ko="];
  };

  inputs = {
    pre-commit-hooks.url = "github:cachix/git-hooks.nix";
    pkgs-2411.url = "github:nixos/nixpkgs/nixos-24.11";
    pkgs-2505.url = "github:nixos/nixpkgs/nixos-25.05";
    stable.follows = "pkgs-2505";
    unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs.follows = "unstable";
    nixos-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    nixGL.url = "github:nix-community/nixGL";
    darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    darwin,
    home-manager,
    ...
  } @ inputs: let
    inherit (inputs.nixpkgs) lib;
    inherit (lib) elem filterAttrs genAttrs intersectLists map mapAttrs mapAttrs' mapAttrsToList mergeAttrsList nameValuePair platforms;

    defaultSystems =
      intersectLists
      (platforms.linux ++ platforms.darwin)
      (platforms.x86_64 ++ platforms.aarch64);
    darwinSystems = intersectLists defaultSystems platforms.darwin;
    linuxSystems = intersectLists defaultSystems platforms.linux;
    eachSystemMap = genAttrs;

    homePrefix = system:
      if (elem system darwinSystems)
      then "/Users"
      else "/home";

    # generate a base darwin configuration with the
    # specified hostname, overlays, and any extraModules applied
    mkDarwinConfig = {
      system ? "aarch64-darwin",
      nixpkgs ? inputs.nixpkgs,
      baseModules ? [
        home-manager.darwinModules.home-manager
        ./modules/darwin
      ],
      extraModules ? [],
    }:
      darwin.lib.darwinSystem {
        inherit system;
        modules = baseModules ++ extraModules;
        specialArgs = {inherit self inputs nixpkgs;};
      };

    # generate a base nixos configuration with the
    # specified overlays, hardware modules, and any extraModules applied
    mkNixosConfig = {
      system ? "x86_64-linux",
      nixpkgs ? inputs.nixos-unstable,
      hardwareModules,
      baseModules ? [
        home-manager.nixosModules.home-manager
        ./modules/nixos
      ],
      extraModules ? [],
    }:
      nixpkgs.lib.nixosSystem {
        inherit system;
        modules = baseModules ++ hardwareModules ++ extraModules;
        specialArgs = {inherit self inputs nixpkgs;};
      };

    # generate a home-manager configuration usable on any unix system
    # with overlays and any extraModules applied
    mkHomeConfig = {
      username,
      system ? "x86_64-linux",
      nixpkgs ? inputs.nixpkgs,
      baseModules ? [
        ./modules/home-manager
        ./modules/nixpkgs.nix
        {
          home = {
            inherit username;
            homeDirectory = "${homePrefix system}/${username}";
          };
        }
      ],
      extraModules ? [],
    }:
      inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          inherit system;
          config = import ./modules/config.nix;
          overlays = [self.overlays.default];
        };
        extraSpecialArgs = {inherit self inputs nixpkgs;};
        modules = baseModules ++ extraModules;
      };
    mkHooks = system:
      inputs.pre-commit-hooks.lib.${system}.run {
        src = ./.;
        hooks = {
          black.enable = true;
          shellcheck.enable = true;
          alejandra.enable = true;
          shfmt.enable = false;
          stylua.enable = true;
          deadnix = {
            enable = true;
            settings = {
              edit = true;
              noLambdaArg = true;
            };
          };
        };
      };
  in {
    checks = mergeAttrsList [
      # verify devShell + pre-commit hooks; need to work on all platforms
      (eachSystemMap defaultSystems (
        system: {
          devShell = self.devShells.${system}.default;
          pre-commit-check = mkHooks system;
        }
      ))
      # home-manager checks; add _home suffix to original config to avoid nixos coflict
      (eachSystemMap defaultSystems (system:
        mapAttrs'
        (name: drv: (nameValuePair "${name}_home" drv.activationPackage))
        (filterAttrs
          (name: drv: lib.strings.hasSuffix system name)
          self.homeConfigurations)))
      # darwin checks; limit these to darwinSystems
      (eachSystemMap darwinSystems (system:
        mapAttrs
        (name: drv: drv.config.system.build.toplevel)
        (filterAttrs
          (name: drv: lib.strings.hasSuffix system name)
          self.darwinConfigurations)))
      # nixos checks; limit these to linuxSystems
      (eachSystemMap linuxSystems (system:
        mapAttrs
        (name: drv: drv.config.system.build.toplevel)
        (filterAttrs
          (name: drv: lib.strings.hasSuffix system name)
          self.nixosConfigurations)))
    ];

    formatter = eachSystemMap defaultSystems (system: (mkHooks system).config.hooks.alejandra.package);

    darwinConfigurations =
      # generate darwin configs for each supported platform
      mergeAttrsList (
        # arch-independent configs that can operate on both x86_64-darwin and aarch64-darwin
        (map
          (system: {
            "kclejeune@${system}" = mkDarwinConfig {
              inherit system;
              extraModules = [./profiles/personal ./modules/darwin/apps.nix];
            };
            "klejeune@${system}" = mkDarwinConfig {
              inherit system;
              extraModules = [
                ./profiles/work
              ];
            };
          })
          darwinSystems)
        # and "custom" ones that aren't universal
        ++ []
      );

    nixosConfigurations =
      # generate nixos configs, if these are ever applicable
      mergeAttrsList [
        {
          "kclejeune@x86_64-linux" = mkNixosConfig {
            system = "x86_64-linux";
            hardwareModules = [
              ./modules/hardware/phil.nix
              inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t460s
            ];
            extraModules = [./profiles/personal];
          };
        }
      ];

    homeConfigurations =
      # generate home-manager configs for each supported platform
      mergeAttrsList (
        (map (system: {
            "kclejeune@${system}" = mkHomeConfig {
              inherit system;
              username = "kclejeune";
              extraModules = [./profiles/personal/home-manager];
            };
            "klejeune@${system}" = mkHomeConfig {
              inherit system;
              username = "klejeune";
              extraModules = [
                ./profiles/work/home-manager
              ];
            };
          })
          defaultSystems)
        # and "custom" ones that aren't universal
        ++ []
      );

    devShells = eachSystemMap defaultSystems (system: let
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [self.overlays.default];
      };
      pre-commit-check = mkHooks system;
    in {
      default = pkgs.mkShell {
        inherit (pre-commit-check) shellHook;
        packages = with pkgs;
          [
            bashInteractive
            fd
            nixd
            ripgrep
            uv
          ]
          ++ (mapAttrsToList (name: value: value) self.packages.${system});
        inputsFrom = pre-commit-check.enabledPackages;
      };
    });

    packages = eachSystemMap defaultSystems (system: let
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [self.overlays.default];
      };
    in {
      sysdo = pkgs.writeShellScriptBin "sysdo" "${pkgs.uv}/bin/uv run -q ${./bin/sysdo.py} $@";
      cb = pkgs.writeShellScriptBin "cb" ''
        #! ${pkgs.lib.getExe pkgs.bash}
        # universal clipboard, stephen@niedzielski.com

        shopt -s expand_aliases

        # ------------------------------------------------------------------------------
        # os utils

        case "$OSTYPE$(uname)" in
          [lL]inux*) TUX_OS=1 ;;
         [dD]arwin*) MAC_OS=1 ;;
          [cC]ygwin) WIN_OS=1 ;;
                  *) echo "unknown os=\"$OSTYPE$(uname)\"" >&2 ;;
        esac

        is_tux() { [ ''${TUX_OS-0} -ne 0 ]; }
        is_mac() { [ ''${MAC_OS-0} -ne 0 ]; }
        is_win() { [ ''${WIN_OS-0} -ne 0 ]; }

        # ------------------------------------------------------------------------------
        # copy and paste

        if is_mac; then
          alias cbcopy=pbcopy
          alias cbpaste=pbpaste
        elif is_win; then
          alias cbcopy=putclip
          alias cbpaste=getclip
        else
          alias cbcopy='${pkgs.xclip}/bin/xclip -sel c'
          alias cbpaste='${pkgs.xclip}/bin/xclip -sel c -o'
        fi

        # ------------------------------------------------------------------------------
        cb() {
          if [ ! -t 0 ] && [ $# -eq 0 ]; then
            # no stdin and no call for --help, blow away the current clipboard and copy
            cbcopy
          else
            cbpaste ''${@:+"$@"}
          fi
        }

        # ------------------------------------------------------------------------------
        if ! return 2>/dev/null; then
          cb ''${@:+"$@"}
        fi
      '';
    });

    apps = eachSystemMap defaultSystems (system: rec {
      sysdo = {
        type = "app";
        program = "${self.packages.${system}.sysdo}/bin/sysdo";
      };
      cb = {
        type = "app";
        program = "${self.packages.${system}.cb}/bin/cb";
      };
      default = sysdo;
    });

    overlays = {
      default = final: prev: {
        sysdo = self.packages.${prev.system}.sysdo;
        cb = self.packages.${prev.system}.cb;
        stable = import inputs.stable {inherit (prev) system;};
        nixVersions = prev.nixVersions // {nix_2_18 = inputs.pkgs-2411.legacyPackages.${prev.system}.nixVersions.nix_2_18;};
      };
    };
  };
}
