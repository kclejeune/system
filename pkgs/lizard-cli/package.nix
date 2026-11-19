{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs_22,
  coreutils,
  gitMinimal,
  gnutar,
  testers,
}:

buildNpmPackage (finalAttrs: {
  pname = "lizard-cli";
  version = "4.0.130";

  src = fetchFromGitHub {
    owner = "lizard-build";
    repo = "lizard-cli";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Vqu7nMsZuJTmNTspeWooPCFcbBCGWCp6hOhSFBwRmFc=";
  };

  nodejs = nodejs_22;
  npmDepsHash = "sha256-MQbvLhWepxeq1JU+pHIWBCTwKcRe5tT3T8g4xM41tRE=";

  makeWrapperArgs = [
    "--set"
    "LIZARD_NO_UPDATE"
    "1"
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath [
      coreutils
      gitMinimal
      gnutar
    ])
  ];

  passthru.tests.version = testers.testVersion { package = finalAttrs.finalPackage; };

  meta = {
    description = "CLI for Lizard apps, databases, and cloud sandboxes";
    homepage = "https://lizard.build";
    changelog = "https://github.com/lizard-build/lizard-cli/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "lizard";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
  };
})
