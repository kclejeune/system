{ inputs, lib, ... }: {
  nixpkgs.overlays = [
    # channels
    (final: prev: {
      # expose other channels via overlays
      stable = import inputs.stable { system = prev.system; };
      trunk = import inputs.trunk { system = prev.system; };
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
            rev = "916d9133f9d13fb38678baa3d0adf3cfb9dff003";
            sha256 = "sha256-RFEuVIMP9+HXnkSPRobCATzg9fsu48zoAFq7AqodLaQ=";
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
