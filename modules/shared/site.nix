{ lib, ... }:
# Site-wide constants shared across hosts, promoted out of per-host literals so
# there's a single source of truth (and a single edit if any ever changes).
#
# Exposed twice because not every consumer is a NixOS module: the terranix
# configs and the deploy-rs node list read `flake.lib.site`, while hosts use
# `config.site.*` and can still override per host.
let
  site = {
    # Public zone (auth, netbird, traceway, …) and the zone the NetBird
    # reverse proxy serves private services under (grafana.kclj.dev, …).
    domain = "kclj.io";
    proxyDomain = "kclj.dev";
    # UniFi's local domain; caddy-lan issues real certs under it.
    lanDomain = "lan.kclj.io";
    # UniFi console / LAN gateway.
    unifiAddr = "192.168.1.1";
    tailnetDomain = "tailf0779.ts.net";
    cloudflareAccountId = "14613cda02f216f5620eca979a286eaf";
    lanCidr = "192.168.1.0/24";
    # Tailscale CGNAT range + this NetBird network's range.
    overlayCidrs = [
      "100.64.0.0/10"
      "10.64.0.0/16"
    ];
  };

  aspect = (import ../_lib.nix).mkAspect {
    name = "site";
    os =
      { lib, ... }:
      {
        options.site = {
          domain = lib.mkOption {
            type = lib.types.str;
            default = site.domain;
            description = "Public DNS zone for internet-facing services.";
          };

          proxyDomain = lib.mkOption {
            type = lib.types.str;
            default = site.proxyDomain;
            description = "Zone the NetBird reverse proxy serves private services under.";
          };

          lanDomain = lib.mkOption {
            type = lib.types.str;
            default = site.lanDomain;
            description = "UniFi's local domain; LAN services get certs under it.";
          };

          unifiAddr = lib.mkOption {
            type = lib.types.str;
            default = site.unifiAddr;
            description = "LAN address of the UniFi console / gateway.";
          };

          tailnetDomain = lib.mkOption {
            type = lib.types.str;
            default = site.tailnetDomain;
            description = "This tailnet's MagicDNS base domain — service VIPs hang under it.";
          };

          cloudflareAccountId = lib.mkOption {
            type = lib.types.str;
            default = site.cloudflareAccountId;
            description = "Cloudflare account id backing the R2 buckets (nimbus cache, restic repos).";
          };

          lanCidr = lib.mkOption {
            type = lib.types.str;
            default = site.lanCidr;
            description = "Home LAN subnet the P3 nodes sit on and advertise as subnet routers.";
          };

          overlayCidrs = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = site.overlayCidrs;
            description = "IPv4 ranges of the Tailscale and NetBird overlays.";
          };
        };
      };
  };
in
lib.recursiveUpdate aspect { flake.lib.site = site; }
