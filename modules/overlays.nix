{ inputs, lib, ... }: {
  nixpkgs.overlays = [
    # channels
    (final: prev: {
      # expose other channels via overlays
      stable = import inputs.stable { system = prev.system; };
    })

    (final: prev: rec {
      # fix yabai for monterey
      # thanks to https://github.com/DieracDelta/flakes/blob/flakes/flake.nix#L382
      yabai =
        let
          buildSymlinks = prev.runCommand "build-symlinks" { } ''
            mkdir -p $out/bin
            ln -s /usr/bin/xcrun /usr/bin/xcodebuild /usr/bin/tiffutil /usr/bin/qlmanage $out/bin
          '';
        in
        prev.yabai.overrideAttrs (old: {
          src = prev.fetchFromGitHub {
            owner = "koekeishiya";
            repo = "yabai";
            rev = "34d31e8c1b6c0969dc4181f521aa2edb8757b805";
            sha256 = "sha256-jX4i+VpLNiRuUfwJE8ys6uMaoHjjb1sa+GyMjTpjCVk=";
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
