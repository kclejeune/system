{
  lib,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  openssl,
}:

rustPlatform.buildRustPackage rec {
  pname = "sem-cli";
  version = "0.25.0";

  src = fetchFromGitHub {
    owner = "Ataraxy-Labs";
    repo = "sem";
    rev = "v${version}";
    hash = "sha256-qv9xLNK74dNhffUgyMDW7stEQgn+NgzBgEHxeyqKvVw=";
  };

  sourceRoot = "${src.name}/crates";

  cargoHash = "sha256-5g77gr5tx6owE+5kzrdg9F1sFEK6GzdtUsuDF3sRi1s=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [ openssl ];

  doCheck = false;

  meta = with lib; {
    description = "Semantic version control CLI — entity-level diffs on top of git";
    homepage = "https://github.com/Ataraxy-Labs/sem";
    changelog = "https://github.com/Ataraxy-Labs/sem/releases/tag/v${version}";
    license = with licenses; [
      mit
      asl20
    ];
    maintainers = [ ];
    mainProgram = "sem";
    platforms = platforms.unix;
  };
}
