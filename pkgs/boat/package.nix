{
  lib,
  stdenvNoCC,
  fetchurl,
  makeBinaryWrapper,
  installShellFiles,
  openssh,
  rsync,
  gnutar,
  xdg-utils,
  testers,
}:
let
  # nixpkgs.box-cli still packages the pre-Boat CLI; boat-cli is an unrelated tool.
  # Upstream publishes binaries only, despite the release repository's MIT license.
  platforms = {
    x86_64-linux = {
      target = "linux-x64";
      hash = "sha256-dmL48sa/MUNdTTZVgevWuEB2tKQAAuORBSAIKiSEFyE=";
    };
    aarch64-linux = {
      target = "linux-arm64";
      hash = "sha256-CXF3hSVC3hrj8pB7Q0xGlJ3ExNGVtoVsG4MY9PDIxzU=";
    };
    aarch64-darwin = {
      target = "darwin-arm64";
      hash = "sha256-bEJAHpH8Cx6nROwCukvoRdBhmjZcrKHZ5jk7kB6H+w4=";
    };
  };
  platform = platforms.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "boat";
  version = "1.0.92";

  src = fetchurl {
    url = "https://github.com/ariana-dot-dev/agent-server/releases/download/boat-cli-v${finalAttrs.version}/boat-${platform.target}";
    inherit (platform) hash;
  };

  licenseFile = fetchurl {
    url = "https://raw.githubusercontent.com/ariana-dot-dev/agent-server/boat-cli-v${finalAttrs.version}/LICENSE";
    hash = "sha256-GahJWb4yW++v+BF5RbGwWKMfMZ4pquBB/HOh1HvPJT0=";
  };

  strictDeps = true;
  dontUnpack = true;
  # Linux releases are static PIEs; preserve the upstream Darwin code signature.
  dontStrip = true;

  nativeBuildInputs = [
    makeBinaryWrapper
    installShellFiles
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/bin/boat"
    install -Dm644 "$licenseFile" "$out/share/doc/boat/LICENSE"
    wrapProgram "$out/bin/boat" \
      --set BOAT_NO_UPDATE 1 \
      --prefix PATH : ${
        lib.makeBinPath (
          [
            openssh
            rsync
            gnutar
          ]
          ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [ xdg-utils ]
        )
      }

    runHook postInstall
  '';

  postInstall = lib.optionalString (stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform) ''
    # Upstream emits a script for `eval`, but compinit needs an autoloadable
    # function named after the completion file and a #compdef header.
    "$out/bin/boat" completions zsh > boat.zsh
    substituteInPlace boat.zsh \
      --replace-fail '# boat shell completion (zsh)' '#compdef boat' \
      --replace-fail '_boat_complete' '_boat' \
      --replace-fail 'compdef _boat boat' ""

    installShellCompletion --cmd boat \
      --bash <("$out/bin/boat" completions bash) \
      --fish <("$out/bin/boat" completions fish) \
      --zsh boat.zsh
  '';

  passthru.tests.version = testers.testVersion { package = finalAttrs.finalPackage; };

  meta = {
    description = "CLI for Boat cloud sandboxes";
    homepage = "https://boat.dev";
    changelog = "https://github.com/ariana-dot-dev/agent-server/releases/tag/boat-cli-v${finalAttrs.version}";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "boat";
    platforms = lib.attrNames platforms;
  };
})
