{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  alsa-lib,
  at-spi2-atk,
  cups,
  gtk3,
  libdrm,
  libgbm,
  libGL,
  libnotify,
  libsecret,
  libusb1,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxkbfile,
  libxrandr,
  nss,
  openssl,
  systemd,
  tpm2-tss,
  vulkan-loader,
  xdg-utils,
}:

let
  version = "26.928.20755";

  # `latest/` is overwritten in place; the apt pool keeps versioned files.
  srcs = {
    x86_64-linux = {
      arch = "amd64";
      hash = "sha256-RYbcGmyGmJgsqFn4aqoWg18zgyoJ4kBC36dVcapg2NE=";
    };
    aarch64-linux = {
      arch = "arm64";
      hash = "sha256-fSqTEblFkzI9bE5tU+E+D8o4tTm+jHJwQSZVrGijIo0=";
    };
  };
  platform =
    srcs.${stdenv.hostPlatform.system}
      or (throw "chatgpt: unsupported system ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "chatgpt";
  inherit version;

  src = fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${version}_${platform.arch}.deb";
    inherit (platform) hash;
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    cups
    gtk3
    libdrm
    libgbm
    libnotify
    libsecret
    libusb1
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxkbfile
    libxrandr
    nss
    openssl
    tpm2-tss
  ];

  # dlopen'd by Chromium, so autoPatchelf can't see them.
  runtimeDependencies = [
    libGL
    (lib.getLib systemd)
    libnotify
    vulkan-loader
  ];

  # Optional Qt theming shims; Chromium falls back to GTK without them.
  autoPatchelfIgnoreMissingDeps = [
    "libQt5*"
    "libQt6*"
  ];

  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share
    cp -r usr/lib/chatgpt $out/lib
    cp -r usr/share/{applications,icons,pixmaps,metainfo} $out/share/ 2>/dev/null || true
    rm -f $out/lib/codex-launcher
    # Unused on glibc and unpatchable.
    find $out/lib -path '*musl*' -name '*.node' -delete

    # Don't let a chat app claim the default web browser.
    substituteInPlace $out/share/applications/chatgpt.desktop \
      --replace-fail "x-scheme-handler/http;x-scheme-handler/https;" ""

    runHook postInstall
  '';

  postFixup = ''
    makeWrapper $out/lib/ChatGPT $out/bin/chatgpt \
      "''${gappsWrapperArgs[@]}" \
      --prefix PATH : ${lib.makeBinPath [ xdg-utils ]} \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"
  '';

  meta = {
    description = "ChatGPT desktop app (Linux preview)";
    homepage = "https://learn.chatgpt.com/docs/linux/linux-app";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = builtins.attrNames srcs;
    mainProgram = "chatgpt";
  };
}
