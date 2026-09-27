{
  lib,
  buildGoModule,
  buildNpmPackage,
  fetchFromGitHub,
}:

let
  version = "2.0.2-dev";

  src = fetchFromGitHub {
    owner = "kclejeune";
    repo = "traceway";
    rev = "3f401cd84a93c522ceadea974fb523d2fe027866";
    hash = "sha256-JRkj7ICFVOCMpeirdcVOo7kvSU5QDUN8GuW+NBjEV1w=";
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
    npmDepsHash = "sha256-UJWw5ZaX8kashSyrxcdHplOIVWxjSNbAz8e9zz1yE6E=";

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
  vendorHash = "sha256-rqbcMj0GJTvmWPsZ7D0DXQH4rsgiJnT369K81Ygtxcc=";

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
