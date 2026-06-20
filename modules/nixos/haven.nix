_: {
  # haven — home-automation node. Runs homebridge (native) and uptime-kuma
  # (native) on the host, and Home Assistant OS as a VM under Incus so HA keeps
  # its supervised add-ons / HACS / UI workflow. The HAOS VM is bridged onto
  # the LAN (br0) as its own device for HomeKit/mDNS discovery.
  flake.nixosModules.haven =
    {
      config,
      ...
    }:
    let
      homebridgeUiPort = 8581;
      uptimeKumaPort = 3001;
      # HAOS VM's own DHCP lease on br0 — reserve it in UniFi so this upstream
      # stays valid. HA also needs use_x_forwarded_for + trusted_proxies (br0
      # IP) in its configuration.yaml to accept the reverse proxy.
      haVmAddr = "192.168.1.60:8123";
    in
    {
      networking.hostName = "haven";

      # --- LAN bridge for the Home Assistant OS VM ---
      # The HAOS VM attaches to br0 so it appears as its own device on the LAN
      # — required for HomeKit/mDNS discovery and matter/thread bridges. The
      # physical NIC is enslaved to br0 (matched by name so we don't hardcode
      # eno1 vs enp*); br0 itself holds the host's DHCP lease. These
      # lower-numbered networkd files win over server-base's 90-dhcp-default
      # for the physical NIC, while br0 picks up the generic match too.
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
        # Static hostname wins; don't let DHCP try to set it (see server-base).
        dhcpV4Config.UseHostname = false;
        linkConfig.RequiredForOnline = "routable";
      };

      # Trust the LAN bridge + overlays. This is a dedicated home-automation
      # node: HomeKit/mDNS (homebridge, HA) needs broad LAN reachability incl.
      # ephemeral HAP accessory ports, which per-port firewall rules can't
      # cleanly express. tailscale0 / wt0 are added as trusted by their own
      # modules. Tighten to specific ports later if the threat model changes.
      networking.firewall.trustedInterfaces = [ "br0" ];

      # Normal user; incus-admin lets it drive `incus` without sudo.
      users.users.${config.user.name} = {
        isNormalUser = true;
        extraGroups = [
          "wheel"
          "incus-admin"
        ];
      };
      # Headless box — keep rescue root SSH keys like the gateway does.
      identity.enableRootSshKeys = true;

      # --- Incus (Home Assistant OS VM) ---
      # The HAOS image is imported imperatively after install (see notes
      # below). Declared here: Incus itself, its web UI, a dir-backed storage
      # pool (root is ext4, not ZFS), and a default profile that bridges VMs
      # onto br0.
      virtualisation.incus = {
        enable = true;
        ui.enable = true;
        preseed = {
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

      # --- HAOS VM bring-up runbook (imperative, run once over SSH) ---
      # Incus instances can't be declared via preseed (it only does pools/
      # profiles/networks), so the HAOS VM is created by hand. Host SSH is
      # already set up (kclejeune@haven / haven.lan.kclj.io), and the LAN
      # bridge + dir pool + br0-bridged `default` profile above are all this
      # needs. We import HAOS as a proper Incus image (split image: a tiny
      # metadata tarball + the qcow2 as rootfs) and launch from it — the
      # canonical route, no raw conversion or poking at root.img.
      #
      # 1. Fetch + decompress the latest HAOS OVA qcow2 (bump the version):
      #      cd /var/tmp
      #      curl -fL -o haos.qcow2.xz \
      #        https://github.com/home-assistant/operating-system/releases/download/18.0/haos_ova-18.0.qcow2.xz
      #      unxz haos.qcow2.xz          # -> haos_ova-18.0.qcow2
      #
      # 2. Build metadata + import as an Incus image:
      #      cat > metadata.yaml <<'EOF'
      #      architecture: x86_64
      #      creation_date: 1700000000
      #      properties:
      #        description: Home Assistant OS
      #        os: HAOS
      #        release: "18.0"
      #      EOF
      #      tar -czf metadata.tar.gz metadata.yaml
      #      incus image import metadata.tar.gz haos_ova-18.0.qcow2 --alias haos
      #
      # 3. Launch the VM. security.secureboot=false because HAOS isn't signed
      #    for Incus secureboot; the `default` profile already bridges eth0
      #    onto br0 so the VM gets its own LAN DHCP lease:
      #      incus launch haos homeassistant --vm \
      #        -c security.secureboot=false -d root,size=32GiB
      #      incus stop homeassistant -f
      #      incus config set homeassistant limits.cpu=2 limits.memory=4GiB
      #      incus config set homeassistant boot.autostart=true
      #      incus start homeassistant
      #      incus console --show-log homeassistant   # watch boot; Ctrl-a q
      #      incus list homeassistant                 # grab eth0 LAN IPv4
      #
      # 4. Restore the previous install: browse to http://<vm-ip>:8123 ->
      #    "Restore from backup" -> upload the HA native .tar (config +
      #    add-ons + HACS). You can't SSH/incus-exec into HAOS directly —
      #    after restore, enable HA's "SSH & Web Terminal" add-on for a shell.
      #
      # 5. Cleanup once it boots clean: rm /var/tmp/haos.* /var/tmp/metadata.*
      #    (the imported image stays cached; see `incus image list`).
      #
      # Resources are deliberately small (2 vCPU / 4 GiB / 32 GiB) — bump via
      # `incus config set` if heavier add-ons (Frigate, etc.) need it.

      # --- Homebridge (native module) ---
      # State at /var/lib/homebridge (covered by the backup module's /var/lib
      # sweep). UI + HAP ports are reachable over the trusted LAN/overlays.
      services.homebridge = {
        enable = true;
        uiSettings.port = homebridgeUiPort;
      };

      # --- Reverse proxy (caddy-lan: ACME DNS-01 + UniFi DDNS) ---
      # unifi/* are now in secrets/haven.yaml, so self-register the proxied
      # subdomains into UniFi local DNS. interface is br0 (haven's physical
      # NIC is enslaved to br0, which holds the host's DHCP lease), not eno*.
      services.caddyLan = {
        enable = true;
        proxies = {
          homebridge = "127.0.0.1:${toString homebridgeUiPort}";
          status = "127.0.0.1:${toString uptimeKumaPort}";
          homeassistant = haVmAddr;
        };
        dynamicDns = {
          enable = true;
          interface = "br0";
        };
      };

      # --- Uptime Kuma (native module) ---
      services.uptime-kuma = {
        enable = true;
        settings = {
          HOST = "0.0.0.0";
          PORT = toString uptimeKumaPort;
        };
      };

      # --- Backups (restic → R2 via the backup module) ---
      # The restic/* secrets and the `system` job are declared by
      # flake.nixosModules.backup; this just points sops at haven's file.
      # NOTE: HAOS's qcow2 under /var/lib/incus is excluded from restic — use
      # Home Assistant's own backup feature (push to R2 or an NFS share on a
      # storage node) for a consistent HA snapshot.
      sops.defaultSopsFile = ../../secrets/haven.yaml;

      system.stateVersion = "25.11";
    };
}
