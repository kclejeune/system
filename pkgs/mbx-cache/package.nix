{
  cacert,
  lib,
  fetchFromGitHub,
  rustPlatform,
}:

rustPlatform.buildRustPackage rec {
  pname = "mbx-cache";
  version = "0.2.0-unstable-2026-11-05";

  # kclejeune/mr-boxington-cache:fix/rustc-driver-and-pack-uploads
  rev = "8ea4181db96556afd1a8027183f973274d1e94cb";
  src = fetchFromGitHub {
    owner = "kclejeune";
    repo = "mr-boxington-cache";
    inherit rev;
    hash = "sha256-TAOCAR2oGfnajfvW3bd003TZ/dvPrjIT5q5XOD6LTZw=";
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
