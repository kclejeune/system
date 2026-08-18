{ lib, ... }:
# Site-wide constants shared across hosts, promoted out of per-host literals so
# there's a single source of truth (and a single edit if any ever changes).
#
# Exposed twice because not every consumer is a NixOS module: the terranix
# configs and the deploy-rs node list read `flake.lib.site`, while hosts use
# `config.site.*` and can still override per host.
let
  site = {
    tailnetDomain = "tailf0779.ts.net";
    cloudflareAccountId = "14613cda02f216f5620eca979a286eaf";
    lanCidr = "192.168.1.0/24";
  };

  aspect = (import ../_lib.nix).mkAspect {
    name = "site";
    os =
      { lib, ... }:
      {
        options.site = {
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
        };
      };
  };
in
lib.recursiveUpdate aspect { flake.lib.site = site; }
