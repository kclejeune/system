{
  cacert,
  lib,
  fetchFromGitHub,
  rustPlatform,
}:

rustPlatform.buildRustPackage rec {
  pname = "mbx-cache";
  version = "0.2.0-unstable-2026-10-26";

  rev = "d8c14c888f67fea17764346b963a688d21f16f95";
  src = fetchFromGitHub {
    owner = "jdx";
    repo = "mr-boxington-cache";
    inherit rev;
    hash = "sha256-F3nD2Al/szsiNEt8WaWiOaeloydId0gPSN+Y3fFxlAU=";
  };

  cargoHash = "sha256-8+Yd7v/erI2hNt5KrknIGaEh6PLjezukD2LkCOYAGE8=";

  env = {
    MBX_CACHE_BUILD_REVISION = rev;
    SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
  };

  meta = {
    description = "Self-hosted remote build cache server for Mr Boxington";
    homepage = "https://github.com/jdx/mr-boxington-cache";
    license = lib.licenses.mit;
    mainProgram = "mbx-cache";
    platforms = lib.platforms.linux;
  };
}
