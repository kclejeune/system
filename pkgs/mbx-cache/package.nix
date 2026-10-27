{
  cacert,
  lib,
  fetchFromGitHub,
  rustPlatform,
}:

rustPlatform.buildRustPackage rec {
  pname = "mbx-cache";
  version = "0.2.0-unstable-2026-10-27";

  # kclejeune/mr-boxington-cache:fix/rustc-driver-and-pack-uploads
  rev = "c9c3f59c39e4570e338f7e60d31f2d501a69f16b";
  src = fetchFromGitHub {
    owner = "kclejeune";
    repo = "mr-boxington-cache";
    inherit rev;
    hash = "sha256-qWnsyH/IxnbqF8YjpTzytLUU85IqLbANQJCQWH8t4Ks=";
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
