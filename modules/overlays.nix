{ inputs, nixpkgs, stable, ... }: {
  nixpkgs.overlays = [
    # channels
    (final: prev: {
      # expose other channels via overlays
      stable = import stable { system = prev.system; };
      trunk = import inputs.trunk { system = prev.system; };
      small = import inputs.small { system = prev.system; };
    })
    # patches for broken packages
    (final: prev: rec {
      nix-zsh-completions = prev.trunk.nix-zsh-completions;
      tree = prev.trunk.tree;
      nix-direnv = prev.trunk.nix-direnv;
    })

    # hacks to install comma and nix-index on aarch64-darwin
    (final: prev: rec {
      nix-index = let
        inherit (prev)
          lib stdenv rustPlatform fetchFromGitHub pkg-config openssl curl;
        inherit (prev.darwin) Security;
      in rustPlatform.buildRustPackage rec {
        pname = "nix-index";
        version = "0.1.3";

        src = fetchFromGitHub {
          owner = "bennofs";
          repo = "nix-index";
          rev = "69f458004a95a609108b4c72da95b6c83d239a42";
          sha256 = "sha256-kExZMd1uhnOFiSqgdPpxp1txo+8MkgnMaGPIiTCCIQk=";
        };

        cargoSha256 = "sha256-GMY+IVNsJNvmQyAls3JF7Z9Bc92sNgNeMzzAN2yRKM8=";

        nativeBuildInputs = [ pkg-config ];
        buildInputs = [ openssl curl ] ++ lib.optional stdenv.isDarwin Security;

        doCheck = !stdenv.isDarwin;

        postInstall = ''
          mkdir -p $out/etc/profile.d
          cp ./command-not-found.sh $out/etc/profile.d/command-not-found.sh
          substituteInPlace $out/etc/profile.d/command-not-found.sh \
            --replace "@out@" "$out"
        '';

        meta = with lib; {
          description = "A files database for nixpkgs";
          homepage = "https://github.com/bennofs/nix-index";
          license = with licenses; [ bsd3 ];
          maintainers = with maintainers; [ bennofs ncfavier ];
        };
      };

      # install comma from shopify repo
      comma = import inputs.comma rec {
        pkgs = final;
        nix = prev.nix_2_3;
        inherit nix-index;
      };
    })

    inputs.neovim-nightly-overlay.overlay
  ];
}
