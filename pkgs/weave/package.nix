{
  lib,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  openssl,
}:

rustPlatform.buildRustPackage rec {
  pname = "weave";
  version = "0.3.6";

  src = fetchFromGitHub {
    owner = "Ataraxy-Labs";
    repo = "weave";
    rev = "v${version}";
    hash = "sha256-VlJUXAXlWpFGlJgAEhhdeX35AZV/G/IJlXEjU/7SfJg=";
  };

  cargoHash = "sha256-ZPe9l3S88idwYrayT5mmagW/VdA0VlUHTDXVyHoOF1w=";

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
