{
  lib,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  openssl,
}:

rustPlatform.buildRustPackage rec {
  pname = "sem-cli";
  version = "0.10.1";

  src = fetchFromGitHub {
    owner = "Ataraxy-Labs";
    repo = "sem";
    rev = "v${version}";
    hash = "sha256-ukz4sfgesGZ4nhUpF4vHjUJvEixutlli6KOxTvnUs3s=";
  };

  sourceRoot = "${src.name}/crates";

  cargoHash = "sha256-NbNIoPqikjbGTGOeCqDc64BBdINEEG5EvohBtSyOLn4=";

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
