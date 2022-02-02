{ inputs, lib, ... }: {
  nixpkgs.overlays = [
    # channels
    (final: prev: {
      # expose other channels via overlays
      stable = import inputs.stable { system = prev.system; };
      trunk = import inputs.trunk { system = prev.system; };
    })

    (final: prev: rec {
      # fix kitty for arm64
      kitty = prev.trunk.kitty;

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

    })
  ];
}
