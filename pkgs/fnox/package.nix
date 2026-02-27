{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  openssl,
}:

rustPlatform.buildRustPackage rec {
  pname = "fnox";
  version = "1.13.0";

  src = fetchFromGitHub {
    owner = "jdx";
    repo = "fnox";
    rev = "v${version}";
    hash = "sha256-IK9WaOq8zJ95pvyIxNjdR5DQkFusK0LnjVq2qhlEi/8=";
  };

  cargoHash = "sha256-CG2TFLC+3sJqjmPaAF6bliURSvfmpicL1kTKNxv51hk=";

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [ openssl ];

  # Some tests require network access or cloud credentials
  doCheck = false;

  # Shell completions require config files that don't exist in build sandbox
  # Users can generate completions manually with: fnox completion <shell>
  # postInstall = ''
  #   installShellCompletion --cmd fnox \
  #     --bash <($out/bin/fnox completion bash) \
  #     --fish <($out/bin/fnox completion fish) \
  #     --zsh <($out/bin/fnox completion zsh)
  # '';

  meta = with lib; {
    description = "Encrypted/remote secret manager with unified interface for development, CI, and production";
    homepage = "https://fnox.jdx.dev";
    changelog = "https://github.com/jdx/fnox/releases/tag/v${version}";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "fnox";
    platforms = platforms.unix;
  };
}
