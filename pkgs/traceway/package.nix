{
  lib,
  buildGoModule,
  buildNpmPackage,
  fetchFromGitHub,
}:

let
  version = "1.9.21-dev";

  src = fetchFromGitHub {
    owner = "kclejeune";
    repo = "traceway";
    rev = "2aa5a5a9911588e051faf73cf144afbb2d6156a0";
    hash = "sha256-DON2Hu4MPhEmpa0FFZv7v/obupo4CzauY10mzx0fkBY=";
  };

  goPackage =
    attrs:
    buildGoModule (
      {
        inherit version src;
        subPackages = [ "cmd/traceway" ];
      }
      // attrs
    );

  # Release tags commit a prebuilt frontend at backend/static/frontend, but
  # build it from source so CLOUD_MODE=false is explicit and the output is
  # reproducible from the SvelteKit sources rather than a committed artifact.
  frontend = buildNpmPackage {
    pname = "traceway-frontend";
    inherit version src;
    sourceRoot = "${src.name}/frontend";
    npmDepsHash = "sha256-UVOkt/PSWUVim4/GaDRsaE6VzPrOs/eGQB0ygpdXkKo=";

    env.CLOUD_MODE = "false";

    installPhase = ''
      runHook preInstall
      cp -r build $out
      runHook postInstall
    '';
  };
  # Pure-Go query/MCP client (`traceway login`, exceptions/logs/metrics
  # queries). Upstream tags cli/v<x> and backend/v<x> on the same commit, so
  # it shares src/version and a bump covers both.
  cli = goPackage {
    pname = "traceway-cli";

    modRoot = "cli";
    vendorHash = "sha256-vTv8jSywVsMal1+zAthLXpaRv+/C0HInCaLA9ToQeFI=";

    env.CGO_ENABLED = 0;

    ldflags = [
      "-s"
      "-w"
      "-X main.version=${version}"
    ];

    meta = {
      description = "Command-line client for Traceway observability";
      homepage = "https://github.com/tracewayapp/traceway";
      license = lib.licenses.mit;
      mainProgram = "traceway";
      platforms = lib.platforms.unix;
    };
  };
in
goPackage {
  pname = "traceway";

  passthru.cli = cli;

  modRoot = "backend";

  # duckdb-go-bindings ships prebuilt static libraries (.a) that `go mod
  # vendor` drops; keep the module cache instead of a vendor tree.
  proxyVendor = true;
  vendorHash = "sha256-w1IkJoKj/4+QmAKVAZzAov1qDFYcXkrhLsA6fn9KWPM=";

  # telemetry_duckdb: SQLite main DB + DuckDB telemetry DB (the `-duckdb`
  # container flavour). DuckDB links those prebuilt glibc static libs, hence
  # CGO.
  tags = [ "telemetry_duckdb" ];
  env.CGO_ENABLED = 1;

  ldflags = [
    "-s"
    "-w"
  ];

  preBuild = ''
    rm -rf static/frontend
    cp -r ${frontend} static/frontend
  '';

  meta = {
    description = "Self-hosted APM: error tracking, logs, metrics, session replay";
    homepage = "https://github.com/tracewayapp/traceway";
    changelog = "https://github.com/tracewayapp/traceway/releases/tag/backend%2Fv${version}";
    license = lib.licenses.mit;
    mainProgram = "traceway";
    platforms = lib.platforms.linux;
  };
}
