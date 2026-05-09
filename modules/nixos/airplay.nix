_: {
  # AirPlay-Mirror / AirPlay-Audio receiver, backed by uxplay(1). DNS-SD
  # discovery is required but intentionally NOT pulled in here — enroll
  # the `avahi` module alongside this one. The assertion below catches
  # misconfiguration at eval time.
  flake.nixosModules.airplay =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.airplay;
    in
    {
      options.services.airplay = {
        enable = lib.mkEnableOption "the uxplay-backed AirPlay mirroring receiver";

        package = lib.mkPackageOption pkgs "uxplay" { };

        name = lib.mkOption {
          type = lib.types.str;
          default = "airplay";
          description = ''
            AirPlay server name advertised to clients (passed via `-n`).
            uxplay appends `@hostname` automatically; pass `-nh` via
            `extraArgs` to suppress the suffix.
          '';
        };

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Open the legacy AirPlay port set: TCP 7000/7001/7100 and
            UDP 6000/6001/7011. uxplay is launched with `-p` so it pins
            to this fixed range instead of picking ephemeral ports,
            which would otherwise make the firewall config unworkable.
          '';
        };

        extraArgs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [
            "-fs"
            "-async"
          ];
          description = "Additional command-line arguments for uxplay(1).";
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.services.avahi.enable;
            message = ''
              services.airplay.enable requires services.avahi.enable = true
              for AirPlay DNS-SD discovery. Enroll the `avahi` nixosModule
              on this host (or set `services.avahi.enable = true` directly).
            '';
          }
        ];

        environment.systemPackages = [ cfg.package ];

        networking.firewall = lib.mkIf cfg.openFirewall {
          allowedTCPPorts = [
            7000
            7001
            7100
          ];
          allowedUDPPorts = [
            6000
            6001
            7011
          ];
        };

        # User-level service: uxplay needs the user's graphical session
        # (DISPLAY/WAYLAND_DISPLAY for the videosink, PipeWire/PulseAudio
        # for the audiosink). Upstream's bundled uxplay.service ships as
        # `WantedBy=default.target` for the same reason.
        systemd.user.services.airplay = {
          description = "uxplay AirPlay receiver";
          wantedBy = [ "default.target" ];
          serviceConfig = {
            Type = "simple";
            ExecStart = lib.escapeShellArgs (
              [
                (lib.getExe cfg.package)
                "-n"
                cfg.name
                "-p"
              ]
              ++ cfg.extraArgs
            );
            Restart = "on-failure";
            RestartSec = 5;
          };
        };
      };
    };
}
