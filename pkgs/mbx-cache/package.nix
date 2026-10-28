{
  cacert,
  lib,
  fetchFromGitHub,
  rustPlatform,
}:

rustPlatform.buildRustPackage rec {
  pname = "mbx-cache";
  version = "0.2.0-unstable-2026-10-28";

  # kclejeune/mr-boxington-cache:fix/rustc-driver-and-pack-uploads
  rev = "ffcb27527c370ca60cd65bc848e717033de7b451";
  src = fetchFromGitHub {
    owner = "kclejeune";
    repo = "mr-boxington-cache";
    inherit rev;
    hash = "sha256-6O+C8PbRhi5ainQGdSZx9v2r2NIjjYo9MJFPS9YZGGs=";
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
