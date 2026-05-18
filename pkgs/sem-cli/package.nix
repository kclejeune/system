{
  lib,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  openssl,
}:

rustPlatform.buildRustPackage rec {
  pname = "sem-cli";
  version = "0.5.5";

  src = fetchFromGitHub {
    owner = "Ataraxy-Labs";
    repo = "sem";
    rev = "v${version}";
    hash = "sha256-HdUnshOx2+rBiX0EhjRDXOPjqBE8lBfc5KQOqSwS25M=";
  };

  sourceRoot = "${src.name}/crates";

  cargoHash = "sha256-g7/uQdl991qgHl9CPtFXGRO25KhezVH4ijh15rvbMCk=";

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
