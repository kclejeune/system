{
  lib,
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  pam,
  bash,
  coreutils,
  getent,
  gnugrep,
  gnused,
  mokutil,
  tpm2-tools,
  util-linux,
}:

let
  # seal.sh only; the unseal script runs on every login, so it gets a minimal PATH.
  sealPath = lib.makeBinPath [
    bash
    coreutils
    gnugrep
    mokutil
    tpm2-tools
  ];
  unsealPath = lib.makeBinPath [
    bash
    coreutils
    getent
    gnugrep
    gnused
    tpm2-tools
    util-linux
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "tpm-keyring-unlock";
  version = "1.4.1";

  src = fetchFromGitHub {
    owner = "dmitriitimoshenko";
    repo = "tpm-keyring-unlock";
    tag = "v${finalAttrs.version}";
    hash = "sha256-zQRqKXUuqYUOp8zE5Zu+kPKUC6JRx0hv+Kpdvw8FaIU=";
  };

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ pam ];

  postPatch = ''
    patchShebangs bin/seal.sh pam/tpm-keyring-unseal.sh

    # Runs via /run/wrappers with PAM's scrubbed env: set PATH and TCTI in-script.
    substituteInPlace pam/tpm-keyring-unseal.sh \
      --replace-fail \
        'set -euo pipefail' \
        'set -euo pipefail; export PATH=${unsealPath} TPM2TOOLS_TCTI=device:/dev/tpmrm0'

    # Always set PAM_AUTHTOK: in our greetd stack it only holds a failed password.
    substituteInPlace pam/pam_tpm_keyring_authtok.c \
      --replace-fail \
        'existing != NULL) {' \
        'existing != NULL && 0) {'
  '';

  buildPhase = ''
    runHook preBuild
    make \
      PREFIX="$out" \
      PAMDIR="$out/lib/security" \
      LIBEXECDIR="$out/libexec/tpm-keyring-unlock" \
      HELPER_PATH=/run/wrappers/bin/tpm-keyring-unseal
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 pam/pam_tpm_keyring_authtok.so \
      "$out/lib/security/pam_tpm_keyring_authtok.so"
    install -Dm700 pam/tpm-keyring-unseal.sh \
      "$out/libexec/tpm-keyring-unlock/tpm-keyring-unseal"
    install -Dm755 bin/seal.sh \
      "$out/libexec/tpm-keyring-unlock/seal.sh"
    install -Dm644 bin/lib.sh \
      "$out/libexec/tpm-keyring-unlock/lib.sh"
    makeWrapper \
      "$out/libexec/tpm-keyring-unlock/seal.sh" \
      "$out/bin/tpm-keyring-seal" \
      --prefix PATH : "${sealPath}"
    install -Dm644 LICENSE "$out/share/licenses/tpm-keyring-unlock/LICENSE"
    install -Dm644 README.md "$out/share/doc/tpm-keyring-unlock/README.md"

    runHook postInstall
  '';

  strictDeps = true;

  meta = {
    description = "TPM-backed unlock of the GNOME login keyring";
    homepage = "https://github.com/dmitriitimoshenko/tpm-keyring-unlock";
    changelog = "https://github.com/dmitriitimoshenko/tpm-keyring-unlock/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = [ ];
    mainProgram = "tpm-keyring-seal";
    platforms = lib.platforms.linux;
  };
})
