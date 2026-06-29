{
  lib,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  openssl,
}:

rustPlatform.buildRustPackage rec {
  pname = "sem-cli";
  version = "0.14.1";

  src = fetchFromGitHub {
    owner = "Ataraxy-Labs";
    repo = "sem";
    rev = "v${version}";
    hash = "sha256-erTyUSzK7Q9eW0NnhDZgnzLq+KdQGVpXB7ZHhpZ8yyU=";
  };

  sourceRoot = "${src.name}/crates";

  cargoHash = "sha256-iNlR24RGjBL4RsMlL10ymc8VjaZxb+vlRAdSwu04VcA=";

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
