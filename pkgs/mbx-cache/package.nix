{
  cacert,
  lib,
  fetchFromGitHub,
  rustPlatform,
}:

rustPlatform.buildRustPackage rec {
  pname = "mbx-cache";
  version = "0.2.0-unstable-2026-10-27";

  # kclejeune/mr-boxington-cache:fix/build-script-schema-5
  rev = "640b6485c249007a8aa64dfbe89cd9be8b90d529";
  src = fetchFromGitHub {
    owner = "kclejeune";
    repo = "mr-boxington-cache";
    inherit rev;
    hash = "sha256-gPdbhMnvGq1XNNTU1V01Syv/LZ88uf9bDrm6kHm7rlw=";
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
