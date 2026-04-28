_: {
  # Heavy desktop-only developer toolkit: compilers, language servers,
  # build/profiling tooling, media, big Python deps, font for terminals.
  # Body is gated on `config.desktop.enable` so importing this from the
  # base default profile is safe — headless hosts evaluate to no-op.
  flake.homeModules.dev-interactive =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      config = lib.mkIf config.desktop.enable {
        home.packages = with pkgs; [
          attic
          basedpyright
          beads
          bento
          cirrus-cli
          clang
          clang-tools
          cmake
          dive
          dix
          ffmpeg
          flamegraph
          flamelens
          flawz
          flyctl
          golangci-lint
          goreleaser
          (lib.hiPrio gotools)
          go-task
          grype
          jetbrains-mono
          kotlin
          luajit
          nixpacks
          nodejs_20
          pyright
          rustup
          trivy
          uv
          (python3.withPackages (
            ps: with ps; [
              httpx
              matplotlib
              networkx
              numpy
              polars
              scipy
            ]
          ))
        ];
      };
    };
}
