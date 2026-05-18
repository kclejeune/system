{
  lib,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  openssl,
}:

rustPlatform.buildRustPackage rec {
  pname = "weave";
  version = "0.3.3";

  src = fetchFromGitHub {
    owner = "Ataraxy-Labs";
    repo = "weave";
    rev = "v${version}";
    hash = "sha256-GKSINiu98bTYjspHqv/6b7VfCI00gfTkhrmlz0PEKk8=";
  };

  cargoHash = "sha256-FoewhLvXTZZYEcNlvjfqHMF87WP5Q8OzHmetep+qh/c=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [ openssl ];

  doCheck = false;

  meta = with lib; {
    description = "Semantic git merge driver that understands code structure";
    homepage = "https://github.com/Ataraxy-Labs/weave";
    changelog = "https://github.com/Ataraxy-Labs/weave/releases/tag/v${version}";
    license = with licenses; [
      mit
      asl20
    ];
    maintainers = [ ];
    mainProgram = "weave";
    platforms = platforms.unix;
  };
}
