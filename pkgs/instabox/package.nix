{
  lib,
  stdenvNoCC,
  fetchurl,
  makeBinaryWrapper,
  installShellFiles,
  gitMinimal,
  openssh,
  mosh,
  xdg-utils,
  testers,
}:
let
  platforms = {
    x86_64-linux = "linux-amd64";
    aarch64-linux = "linux-arm64";
    aarch64-darwin = "darwin-arm64";
  };
  target = platforms.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "instabox";
  version = "0.8.298";

  # npm is upstream's release channel and bundles the native Go CLI for each
  # platform. Install it directly without the Node onboarding/skills installer.
  src = fetchurl {
    url = "https://registry.npmjs.org/instabox/-/instabox-${finalAttrs.version}.tgz";
    hash = "sha256-YB1XyR/tucs27Yv2TXkBLQOxzw/RszL0e4x5wCWRuow=";
  };

  strictDeps = true;
  dontConfigure = true;
  dontBuild = true;
  # Linux binaries are static; preserve upstream's Darwin code signature.
  dontStrip = true;

  nativeBuildInputs = [
    makeBinaryWrapper
    installShellFiles
  ];

  # Completion generation during the build must not send usage telemetry.
  env.INSTABOX_NO_TELEMETRY = "1";

  installPhase = ''
    runHook preInstall

    install -Dm755 "cli/instabox-${target}" "$out/bin/instabox"
    install -Dm644 LICENSE "$out/share/doc/instabox/LICENSE"
    wrapProgram "$out/bin/instabox" \
      --set INSTABOX_NO_UPDATE_CHECK 1 \
      --prefix PATH : ${
        lib.makeBinPath (
          [
            gitMinimal
            openssh
            mosh
          ]
          ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [ xdg-utils ]
        )
      }

    runHook postInstall
  '';

  postInstall = lib.optionalString (stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform) ''
    installShellCompletion --cmd instabox \
      --bash <("$out/bin/instabox" completion bash) \
      --fish <("$out/bin/instabox" completion fish) \
      --zsh <("$out/bin/instabox" completion zsh)
  '';

  passthru.tests.version = testers.testVersion { package = finalAttrs.finalPackage; };

  meta = {
    description = "CLI for InstaBox cloud sandboxes";
    homepage = "https://instabox.sh";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "instabox";
    platforms = lib.attrNames platforms;
  };
})
