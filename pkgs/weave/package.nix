{
  lib,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  openssl,
}:

rustPlatform.buildRustPackage rec {
  pname = "weave";
  version = "0.3.2";

  src = fetchFromGitHub {
    owner = "Ataraxy-Labs";
    repo = "weave";
    rev = "v${version}";
    hash = "sha256-NlBHoxDgiNF38ktx2d44BmdABrPh4wr52mkNjlAmtX0=";
  };

  cargoHash = "sha256-XUasm/j9FOH9vDqSt1mYBfk3Y9UFKyFb8EKovptXYbI=";

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
