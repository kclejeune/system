{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  openssl,
  perl,
  udev,
}:

rustPlatform.buildRustPackage rec {
  pname = "fnox";
  version = "1.28.0";

  src = fetchFromGitHub {
    owner = "jdx";
    repo = "fnox";
    rev = "v${version}";
    hash = "sha256-S70a68J/Gh7kK22oxqznHDol8S9v+MYuITLI2BXjLxc=";
  };

  cargoHash = "sha256-9LLySyA0eFLoZGUpYh2y8TgQ3htXjeTXisazf1GQgyE=";

  nativeBuildInputs = [
    pkg-config
    perl
  ];

  buildInputs = [ openssl ] ++ lib.optionals stdenv.hostPlatform.isLinux [ udev ];

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
