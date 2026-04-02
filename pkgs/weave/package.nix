{
  lib,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  openssl,
}:

rustPlatform.buildRustPackage rec {
  pname = "weave";
  version = "0.2.7";

  src = fetchFromGitHub {
    owner = "Ataraxy-Labs";
    repo = "weave";
    rev = "v${version}";
    hash = "sha256-K10yGylbbwX42dTlkHOHUxnlHoVXSvp9gI0TUmMAHug=";
  };

  cargoHash = "sha256-NtoRGvF8FWcQkrmNbeut1cU66ob8iNVpl3WJ35avDBk=";

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
