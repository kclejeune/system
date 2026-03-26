{
  lib,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  openssl,
  perl,
}:

rustPlatform.buildRustPackage rec {
  pname = "fnox";
  version = "1.19.0";

  src = fetchFromGitHub {
    owner = "jdx";
    repo = "fnox";
    rev = "v${version}";
    hash = "sha256-I3Qi0KItSBIJ2qHd4M4qsZYT1JZuo9FcfhvWDuGX/18=";
  };

  cargoHash = "sha256-4ZHB1N+9hTcC75RvSnjx8rZfwgXRgz27fCytMnKWDZw=";

  nativeBuildInputs = [
    pkg-config
    perl
  ];

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
