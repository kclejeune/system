_: {
  flake.nixosModules.netbird-proxy =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.netbird-proxy;
      serviceName = "netbird-proxy";
      stateDir = "/var/lib/${cfg.stateDirectory}";
      clientStateDir = "${stateDir}/state";
      certificateDir = "${stateDir}/certificates";

      migratePodmanVolumes = pkgs.writeShellApplication {
        name = "netbird-proxy-migrate-podman-volumes";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          marker=${lib.escapeShellArg "${stateDir}/.podman-volumes-migrated"}
          if [[ -e "$marker" ]]; then
            exit 0
          fi

          if [[ -d ${lib.escapeShellArg cfg.migration.stateVolumePath} ]]; then
            cp -a --no-preserve=ownership \
              ${lib.escapeShellArg "${cfg.migration.stateVolumePath}/."} \
              ${lib.escapeShellArg "${clientStateDir}/"}
          fi
          if [[ -d ${lib.escapeShellArg cfg.migration.certificateVolumePath} ]]; then
            cp -a --no-preserve=ownership \
              ${lib.escapeShellArg "${cfg.migration.certificateVolumePath}/."} \
              ${lib.escapeShellArg "${certificateDir}/"}
          fi

          chown -R ${lib.escapeShellArg "${serviceName}:${serviceName}"} ${lib.escapeShellArg stateDir}
          chmod 0700 ${lib.escapeShellArg stateDir} ${lib.escapeShellArg clientStateDir} ${lib.escapeShellArg certificateDir}
          touch "$marker"
          chown ${lib.escapeShellArg "${serviceName}:${serviceName}"} "$marker"
        '';
      };
    in
    {
      options.services.netbird-proxy = {
        enable = lib.mkEnableOption "the NetBird public reverse proxy";

        package = lib.mkPackageOption pkgs "netbird-proxy" { };

        environment = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "Non-secret environment variables passed to netbird-proxy.";
        };

        environmentFiles = lib.mkOption {
          type = lib.types.listOf lib.types.path;
          default = [ ];
          description = "Environment files containing netbird-proxy secrets.";
        };

        stateDirectory = lib.mkOption {
          type = lib.types.strMatching "[A-Za-z0-9_.-]+";
          default = serviceName;
          description = "Directory below /var/lib used for proxy state and certificates.";
        };

        migration = {
          enable = lib.mkEnableOption "one-time migration from the former Podman volumes";

          stateVolumePath = lib.mkOption {
            type = lib.types.str;
            default = "/var/lib/containers/storage/volumes/netbird-proxy-state/_data";
            description = "Host path of the former Podman state volume.";
          };

          certificateVolumePath = lib.mkOption {
            type = lib.types.str;
            default = "/var/lib/containers/storage/volumes/netbird-proxy-certs/_data";
            description = "Host path of the former Podman certificate volume.";
          };
        };
      };

      config = lib.mkIf cfg.enable {
        users.users.${serviceName} = {
          isSystemUser = true;
          group = serviceName;
          home = stateDir;
        };
        users.groups.${serviceName} = { };

        systemd.tmpfiles.rules = [
          "d ${stateDir} 0700 ${serviceName} ${serviceName} - -"
          "d ${clientStateDir} 0700 ${serviceName} ${serviceName} - -"
          "d ${certificateDir} 0700 ${serviceName} ${serviceName} - -"
        ];

        systemd.services.netbird-proxy-migrate = lib.mkIf cfg.migration.enable {
          description = "Migrate NetBird proxy state from Podman volumes";
          before = [ "netbird-proxy.service" ];
          after = [ "podman-netbird-proxy.service" ];
          conflicts = [ "podman-netbird-proxy.service" ];
          unitConfig.ConditionPathExists = cfg.migration.stateVolumePath;
          serviceConfig = {
            Type = "oneshot";
            ExecStart = lib.getExe migratePodmanVolumes;
            RemainAfterExit = true;

            NoNewPrivileges = true;
            PrivateDevices = true;
            PrivateTmp = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectKernelLogs = true;
            ProtectControlGroups = true;
            ProtectClock = true;
            ProtectHostname = true;
            RestrictAddressFamilies = [ "AF_UNIX" ];
            RestrictNamespaces = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            LockPersonality = true;
            CapabilityBoundingSet = [
              "CAP_CHOWN"
              "CAP_DAC_OVERRIDE"
              "CAP_FOWNER"
            ];
            ReadWritePaths = [ stateDir ];
            SystemCallFilter = [ "@system-service" ];
            SystemCallArchitectures = "native";
            UMask = "0077";
          };
        };

        systemd.services.netbird-proxy = {
          description = "NetBird public reverse proxy";
          wantedBy = [ "multi-user.target" ];
          wants = [ "network-online.target" ];
          after = [
            "network-online.target"
            "netbird-management.service"
          ]
          ++ lib.optional cfg.migration.enable "netbird-proxy-migrate.service";
          requires = lib.optional cfg.migration.enable "netbird-proxy-migrate.service";
          conflicts = [ "podman-netbird-proxy.service" ];
          restartTriggers = [ cfg.package ];
          environment = cfg.environment // {
            HOME = clientStateDir;
            NB_STATE_DIR = clientStateDir;
            NB_PROXY_CERTIFICATE_DIRECTORY = certificateDir;
            NB_PROXY_GEO_DATA_DIR = "${clientStateDir}/geolocation";
          };
          serviceConfig = {
            ExecStart = lib.getExe cfg.package;
            EnvironmentFile = cfg.environmentFiles;
            Restart = "always";
            RestartSec = "5s";
            TimeoutStopSec = "45s";

            User = serviceName;
            Group = serviceName;
            StateDirectory = cfg.stateDirectory;
            StateDirectoryMode = "0700";
            WorkingDirectory = stateDir;

            # Match the former rootless/read-only container and further limit
            # access to host devices, kernel state and process information.
            NoNewPrivileges = true;
            PrivateDevices = true;
            TemporaryFileSystem = [
              "/tmp:rw,nosuid,nodev,noexec,size=64M"
              "/var/tmp:rw,nosuid,nodev,noexec,size=64M"
            ];
            ProtectSystem = "strict";
            ProtectHome = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectKernelLogs = true;
            ProtectControlGroups = true;
            ProtectClock = true;
            ProtectHostname = true;
            ProtectProc = "invisible";
            RestrictAddressFamilies = [
              "AF_INET"
              "AF_INET6"
              "AF_NETLINK"
              "AF_UNIX"
            ];
            RestrictNamespaces = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            LockPersonality = true;
            MemoryDenyWriteExecute = true;
            CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
            AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
            SystemCallFilter = [ "@system-service" ];
            SystemCallArchitectures = "native";
            UMask = "0077";
          };
        };
      };
    };
}
