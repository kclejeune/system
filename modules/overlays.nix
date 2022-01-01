{ inputs, nixpkgs, stable, lib, ... }: {
  nixpkgs.overlays = [
    # channels
    (final: prev: {
      # expose other channels via overlays
      stable = import stable { system = prev.system; };
      trunk = import inputs.trunk { system = prev.system; };
    })

    (final: prev: {
      # expose other channels via overlays
      ripgrep-all = prev.stable.ripgrep-all;
    })
    # hacks to install comma and nix-index on aarch64-darwin
    (final: prev: rec {
      # fix yabai for monterey
      # thanks to https://github.com/DieracDelta/flakes/blob/flakes/flake.nix#L382
      yabai = let
        buildSymlinks = prev.runCommand "build-symlinks" { } ''
          mkdir -p $out/bin
          ln -s /usr/bin/xcrun /usr/bin/xcodebuild /usr/bin/tiffutil /usr/bin/qlmanage $out/bin
        '';
      in prev.yabai.overrideAttrs (old: {
        src = prev.fetchFromGitHub {
          owner = "koekeishiya";
          repo = "yabai";
          rev = "b884717b2d5731f5b4ac164e7c0260076698b08c";
          sha256 = "sha256-kMPf+g+7nMZyu2bkazhjuaZJVUiEoJrgxmxXhL/jC8M=";
        };
        buildInputs = with prev.darwin.apple_sdk.frameworks; [
          Carbon
          Cocoa
          ScriptingBridge
          prev.xxd
          SkyLight
        ];
        nativeBuildInputs = [ buildSymlinks ];
      });

      nix-index = if prev.stdenvNoCC.isDarwin then
        (let
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
          buildInputs = [ openssl curl ]
            ++ lib.optional stdenv.isDarwin Security;

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
        })
      else
        prev.nix-index;

      # install comma from shopify repo
      comma = import inputs.comma rec {
        pkgs = final;
        nix = prev.nix_2_3;
        inherit nix-index;
      };
    })
  ];
}
