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

      # The upstream module links each generated localConfig file into a scanned
      # dir as `<store-hash>-<name>.yaml` via a tmpfiles `L+` rule, but never
      # removes the old-hash link when the content changes across a rebuild — so
      # parsers/scenarios with duplicate names pile up (CrowdSec then warns and
      # ignores one of them). Wipe every nix-store-pointing symlink from the
      # scanned dirs (hub links point at /var/lib and are left alone), then let
      # tmpfiles recreate only the current generation's. Wired as an activation
      # script (below) rather than tied to crowdsec start: a whitelist/parser-only
      # change doesn't alter crowdsec's unit, so it wouldn't restart on that
      # switch — yet that's exactly when a stale link appears. Activation runs on
      # every switch and boot, so the prune always fires when it's needed.
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
          # Run the local API server so bouncers can pull decisions (overrides
          # the upstream module's `mkDefault false`).
          general.api.server.enable = true;
          # Credentials must live in a crowdsec-owned dir: the setup script
          # writes them as the crowdsec user on first boot, but /var/lib/crowdsec
          # is root-owned (writes fail "permission denied"). /etc/crowdsec is
          # crowdsec's stock location and the module owns it correctly.
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

        # The nixpkgs module never writes /etc/crowdsec/config.yaml (it passes the
        # daemon `-c <store path>`), so a bare `cscli` — used by the
        # firewall-bouncer's register oneshot and interactive admin — fails with
        # "no such file". Symlink the default path at the daemon's own config.
        systemd.tmpfiles.settings."99-crowdsec-cscli-config"."/etc/crowdsec/config.yaml"."L+".argument =
          toString
            ((pkgs.formats.yaml { }).generate "crowdsec.yaml" config.services.crowdsec.settings.general);

        # Drop stale localConfig links on every activation (after /etc is the new
        # generation, so the current tmpfiles config is in place). See
        # pruneLocalConfig above for the why.
        system.activationScripts.crowdsec-prune-localconfig = {
          deps = [ "etc" ];
          text = "${pruneLocalConfig}";
        };

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
          crowdsec.serviceConfig = {
            DynamicUser = lib.mkForce false;
            # Upstream sets RestartSec but no Restart=, so a crashed engine stays
            # down and stops producing decisions — silently disabling detection.
            # Auto-recover so detection isn't lost on a transient failure.
            Restart = lib.mkDefault "on-failure";
          };

          # The bouncer enforces decisions at nftables; if it dies the drop-set
          # goes stale and no new bans apply while the engine keeps detecting
          # into the void. Upstream sets no Restart= either, so add one — this is
          # the enforcement floor to the engine's detection floor above.
          crowdsec-firewall-bouncer = lib.mkIf config.services.crowdsec-firewall-bouncer.enable {
            serviceConfig = {
              Restart = lib.mkDefault "on-failure";
              RestartSec = lib.mkDefault 10;
            };
          };

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
