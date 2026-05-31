_: {
  # Reusable CrowdSec base: enables the engine with a local API server and a
  # declarative way to register bouncers from a pre-shared key file. Importing
  # this module provides the capability; a host opts in with
  # `services.crowdsec.enable = true`. No log acquisitions are configured here,
  # so by default CrowdSec only serves the community/CAPI blocklist.
  flake.nixosModules.crowdsec =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.crowdsec;
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
        # Refresh the hub (parser/scenario/collection definitions) daily so
        # detection logic stays current between rebuilds, not just on restart.
        services.crowdsec.autoUpdateService = lib.mkDefault true;

        # openFirewall is intentionally left at its default (false): the LAPI
        # and prometheus endpoints bind 127.0.0.1 and are reached locally (the
        # bouncer over host networking, prometheus over loopback). Enabling it
        # would expose those ports on all interfaces — a regression on a
        # public-facing host. Only set it if the LAPI must serve remote bouncers.

        # Baseline collection; hosts may override the whole list.
        services.crowdsec.hub.collections = lib.mkDefault [ "crowdsecurity/linux" ];

        services.crowdsec.settings = {
          # Run the local API server so bouncers can pull decisions. Normal
          # priority to override the upstream module's `mkDefault false`.
          general.api.server.enable = true;
          # The module's setup script writes machine + online (CAPI)
          # credentials here on first boot (`cscli machine add --auto` and
          # `cscli capi register`); CAPI registration is what pulls the
          # community blocklist. These MUST live in a crowdsec-owned directory:
          # /etc/crowdsec is created by the module's tmpfiles owned by the
          # crowdsec user (and is crowdsec's stock location for these files),
          # whereas /var/lib/crowdsec itself is a root-owned parent, so writing
          # there fails with "permission denied".
          lapi.credentialsFile = lib.mkDefault "/etc/crowdsec/local_api_credentials.yaml";
          capi.credentialsFile = lib.mkDefault "/etc/crowdsec/online_api_credentials.yaml";
        };

        # Never ban our own infrastructure: whitelist loopback + RFC1918 at the
        # parse stage so no scenario can produce a decision for them. A banned
        # 127.0.0.1 is catastrophic — the firewall bouncer drops all loopback
        # traffic, taking down everything proxied over it. Hosts can append more
        # ranges (e.g. overlay networks) via the same list option.
        services.crowdsec.localConfig.parsers.s02Enrich = [
          {
            name = "crowdsec/trusted-loopback-private";
            description = "Whitelist loopback and RFC1918 source IPs";
            whitelist = {
              reason = "trusted infrastructure (loopback / RFC1918)";
              ip = [
                "127.0.0.1"
                "::1"
              ];
              cidr = [
                "10.0.0.0/8"
                "172.16.0.0/12"
                "192.168.0.0/16"
              ];
            };
          }
        ];

        # The nixpkgs module passes the daemon its config via `-c <store path>`
        # and never writes /etc/crowdsec/config.yaml, so a bare `cscli` (no -c)
        # fails with "open /etc/crowdsec/config.yaml: no such file". That breaks
        # the firewall-bouncer's register oneshot (which calls raw cscli) and
        # interactive admin use. Symlink the default path at the *same*
        # generated config the daemon uses so bare cscli just works.
        systemd.tmpfiles.settings."99-crowdsec-cscli-config"."/etc/crowdsec/config.yaml"."L+".argument =
          toString
            ((pkgs.formats.yaml { }).generate "crowdsec.yaml" config.services.crowdsec.settings.general);

        # systemd.services gets the static-user pin plus one idempotent
        # registration oneshot per declared bouncer. cscli is the wrapper
        # installed by services.crowdsec; it sudo's to the crowdsec user, which
        # owns the LAPI database.
        systemd.services = {
          # The upstream module pairs DynamicUser=true with a static
          # User=crowdsec. The (tmpfiles-managed) state dir then lives under
          # /var/lib/private/crowdsec owned by a uid that only lines up right
          # after a full activation — a plain `systemctl restart` or reboot
          # leaves it owned by a stale/unmapped uid, so the service fails with
          # "permission denied" (and, once the dir is gone, NAMESPACE errors) on
          # the state dir. Pin to the static crowdsec user so ownership is stable
          # across restarts and reboots; the user's group memberships
          # (systemd-journal, plus any host SupplementaryGroups) then apply too.
          crowdsec.serviceConfig.DynamicUser = lib.mkForce false;

          # The firewall-bouncer's register oneshot runs as User=crowdsec but
          # with DynamicUser=true and StateDirectory="...crowdsec", so it seizes
          # /var/lib/crowdsec (via /var/lib/private) under a transient uid and
          # fights the now-static crowdsec service for ownership of that shared
          # dir. Pin it static too so there is a single, stable owner.
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
