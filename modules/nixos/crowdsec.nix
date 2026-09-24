_: {
  # CrowdSec base: LAPI plus declarative bouncer registration. Hosts opt in
  # with services.crowdsec.enable and add their own acquisitions.
  flake.nixosModules.crowdsec =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.crowdsec;

      # Upstream links localConfig files as <hash>-<name>.yaml but never removes
      # old-hash links, so duplicates pile up. Prune them on every activation, not
      # crowdsec start: a parser-only change doesn't restart the unit.
      pruneLocalConfig = pkgs.writeShellScript "crowdsec-prune-localconfig" ''
        for dir in \
          /etc/crowdsec/parsers/s00-raw \
          /etc/crowdsec/parsers/s01-parse \
          /etc/crowdsec/parsers/s02-enrich \
          /etc/crowdsec/scenarios \
          /etc/crowdsec/postoverflows/s01-whitelist \
          /etc/crowdsec/contexts \
          /etc/crowdsec/notifications; do
          [ -d "$dir" ] && ${pkgs.findutils}/bin/find "$dir" -maxdepth 1 -type l -lname '/nix/store/*' -delete
        done
        ${config.systemd.package}/bin/systemd-tmpfiles --create /etc/tmpfiles.d/10-crowdsec.conf
      '';
    in
    {
      options.services.crowdsec.declarativeBouncers = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options.keyFile = lib.mkOption {
              type = lib.types.path;
              description = ''
                Path to a file holding the bouncer's pre-shared API key (e.g. a
                sops secret). A `crowdsec-register-<name>` oneshot registers the
                bouncer with this key, so the bouncer and LAPI share it
                declaratively without a manual `cscli bouncers add`.
              '';
            };
          }
        );
        default = { };
        description = ''
          Bouncers to register with the local API using a pre-shared key.
          The attribute name is the bouncer name passed to `cscli bouncers add`.
        '';
      };

      config = lib.mkIf cfg.enable {
        # Keep detection current between rebuilds.
        services.crowdsec.autoUpdateService = lib.mkDefault true;

        # Off: LAPI and metrics are loopback-only.

        services.crowdsec.hub.collections = lib.mkDefault [ "crowdsecurity/linux" ];

        services.crowdsec.settings = {
          general.api.server.enable = true;
          # /var/lib/crowdsec is root-owned and the setup script writes as crowdsec.
          lapi.credentialsFile = lib.mkDefault "/etc/crowdsec/local_api_credentials.yaml";
          capi.credentialsFile = lib.mkDefault "/etc/crowdsec/online_api_credentials.yaml";
        };

        # A banned 127.0.0.1 would make the bouncer drop all loopback traffic.
        services.crowdsec.localConfig.parsers.s02Enrich = [
          {
            name = "crowdsec/trusted-loopback-private";
            description = "Whitelist loopback and RFC1918 source IPs";
            whitelist = {
              reason = "trusted infrastructure (loopback / RFC1918)";
              ip = [ "::1" ];
              cidr = [
                "127.0.0.0/8"
                "10.0.0.0/8"
                "172.16.0.0/12"
                "192.168.0.0/16"
              ];
            };
          }
        ];

        # The module passes -c <store path>, so bare `cscli` (bouncer registration,
        # admin) needs this.
        systemd.tmpfiles.settings."99-crowdsec-cscli-config"."/etc/crowdsec/config.yaml"."L+".argument =
          toString
            ((pkgs.formats.yaml { }).generate "crowdsec.yaml" config.services.crowdsec.settings.general);

        # After /etc switches, so the current tmpfiles config is in place.
        system.activationScripts.crowdsec-prune-localconfig = {
          deps = [ "etc" ];
          text = "${pruneLocalConfig}";
        };

        systemd.services = {
          # DynamicUser + static User leaves the state dir owned by a stale uid after
          # a plain restart or reboot; pin the static user so ownership is stable.
          crowdsec.serviceConfig = {
            DynamicUser = lib.mkForce false;
            # Upstream sets no Restart=, so a crash silently disables detection.
            Restart = lib.mkDefault "on-failure";
          };

          # Likewise for enforcement: a dead bouncer leaves bans stale.
          crowdsec-firewall-bouncer = lib.mkIf config.services.crowdsec-firewall-bouncer.enable {
            serviceConfig = {
              Restart = lib.mkDefault "on-failure";
              RestartSec = lib.mkDefault 10;
            };
          };

          # DynamicUser here would fight the static crowdsec service over
          # /var/lib/crowdsec.
          crowdsec-firewall-bouncer-register = lib.mkIf config.services.crowdsec-firewall-bouncer.enable {
            serviceConfig.DynamicUser = lib.mkForce false;
          };
        }
        // lib.mapAttrs' (
          name: bouncer:
          lib.nameValuePair "crowdsec-register-${name}" {
            description = "Register the ${name} CrowdSec bouncer";
            after = [ "crowdsec.service" ];
            requires = [ "crowdsec.service" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            script = ''
              key="$(cat ${bouncer.keyFile})"
              cscli=/run/current-system/sw/bin/cscli
              if ! "$cscli" bouncers list -o raw | grep -q '^${name},'; then
                "$cscli" bouncers add ${name} --key "$key"
              fi
            '';
          }
        ) cfg.declarativeBouncers;
      };
    };
}
