_: {
  # haven — home automation: homebridge and uptime-kuma natively, Home
  # Assistant OS in an Incus VM bridged onto the LAN for HomeKit/mDNS.
  flake.nixosModules.haven =
    {
      config,
      ...
    }:
    let
      homebridgeUiPort = 8581;
      uptimeKumaPort = 3001;
      # The HAOS VM's lease; reserve it in UniFi. HA must trust haven's br0 IP
      # as a proxy (use_x_forwarded_for in the VM's configuration.yaml).
      haVmAddr = "192.168.1.60:8123";
    in
    {
      networking.hostName = "haven";

      # br0 carries the host's lease and the HAOS VM. Lower-numbered than
      # server-base's 90-dhcp-default so it wins for the NIC.
      systemd.network.netdevs."10-br0".netdevConfig = {
        Name = "br0";
        Kind = "bridge";
      };
      systemd.network.networks."10-br0-members" = {
        matchConfig.Name = "en* eth*";
        networkConfig.Bridge = "br0";
        linkConfig.RequiredForOnline = "enslaved";
      };
      systemd.network.networks."20-br0" = {
        matchConfig.Name = "br0";
        networkConfig.DHCP = "yes";
        # Static hostname wins; don't let DHCP try to set it.
        dhcpV4Config.UseHostname = false;
        linkConfig.RequiredForOnline = "routable";
      };

      # homebridge and status have their own logins. hass/incus stay off serve:
      # incus's OIDC redirect is pinned to its LAN name, and HAOS owns its hostname.
      services.tailscale.serve.services = {
        homebridge.endpoints."tcp:443" = "http://127.0.0.1:${toString homebridgeUiPort}";
        status.endpoints."tcp:443" = "http://127.0.0.1:${toString uptimeKumaPort}";
      };

      # Homebridge child bridges pick HAP ports at runtime, so br0 is trusted
      # wholesale; the web UIs therefore bind loopback behind caddy-lan / serve.
      networking.firewall.trustedInterfaces = [ "br0" ];

      # Drive incus without sudo.
      users.users.${config.user.name}.extraGroups = [
        "wheel"
        "incus-admin"
      ];

      virtualisation.incus = {
        enable = true;
        ui.enable = true;
        preseed = {
          # Loopback only; Caddy is the sole ingress. Incus LTS has no per-user
          # authorization, so any OIDC login is admin — the gate is Authelia's
          # lldap_admin-only `incus` client. Public client: nothing secret here.
          config = {
            "core.https_address" = "127.0.0.1:8443";
            "oidc.issuer" = "https://auth.${config.site.domain}";
            "oidc.client.id" = "incus";
            # Must match the Authelia client's audience.
            "oidc.audience" = "https://incus.${config.site.lanDomain}";
            # Exactly the scopes the Authelia client allows: Incus's default adds
            # `groups`, which Authelia rejects as invalid_scope.
            "oidc.scopes" = "openid offline_access email profile";
          };
          storage_pools = [
            {
              name = "default";
              driver = "dir";
            }
          ];
          profiles = [
            {
              name = "default";
              devices = {
                eth0 = {
                  name = "eth0";
                  type = "nic";
                  nictype = "bridged";
                  parent = "br0";
                };
                root = {
                  path = "/";
                  pool = "default";
                  type = "disk";
                };
              };
            }
          ];
        };
      };

      # HAOS VM bring-up (imperative: Incus preseed can't declare instances):
      #   cd /var/tmp
      #   curl -fL -o haos.qcow2.xz \
      #     https://github.com/home-assistant/operating-system/releases/download/18.0/haos_ova-18.0.qcow2.xz
      #   unxz haos.qcow2.xz
      #   cat > metadata.yaml <<'EOF'
      #   architecture: x86_64
      #   creation_date: 1700000000
      #   properties:
      #     description: Home Assistant OS
      #     os: HAOS
      #     release: "18.0"
      #   EOF
      #   tar -czf metadata.tar.gz metadata.yaml
      #   incus image import metadata.tar.gz haos.qcow2 --alias haos
      #   incus launch haos homeassistant --vm \
      #     -c security.secureboot=false -d root,size=32GiB   # HAOS isn't signed for Incus
      #   incus stop homeassistant -f
      #   incus config set homeassistant limits.cpu=2 limits.memory=4GiB
      #   incus config set homeassistant boot.autostart=true
      #   incus start homeassistant
      # Then restore the HA backup at http://<vm-ip>:8123; enable the "SSH & Web
      # Terminal" add-on for a shell.

      services.homebridge = {
        enable = true;
        uiSettings = {
          host = "127.0.0.1";
          port = homebridgeUiPort;
        };
      };

      # status and incus need UniFi Local DNS Records -> haven; the rest resolve
      # via DHCP hostnames.
      services.caddyLan.proxies = {
        homebridge = "127.0.0.1:${toString homebridgeUiPort}";
        status = "127.0.0.1:${toString uptimeKumaPort}";
        # Not `homeassistant`: UniFi auto-registers that name for the VM's own lease.
        hass = haVmAddr;
        # https:// upstream: incusd serves a self-signed cert on loopback.
        incus = "https://127.0.0.1:8443";
      };

      services.uptime-kuma = {
        enable = true;
        settings.PORT = toString uptimeKumaPort;
      };

      # Once backup is enrolled, exclude the HAOS qcow2 under /var/lib/incus and
      # rely on HA's own backups for a consistent snapshot.
      sops.defaultSopsFile = ../../secrets/haven.yaml;
    };
}
