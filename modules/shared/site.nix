_:
# Site-wide constants shared across hosts, promoted out of per-host literals so
# there's a single source of truth (and a single edit if any ever changes).
(import ../_lib.nix).mkAspect {
  name = "site";
  os =
    { lib, ... }:
    {
      options.site = {
        tailnetDomain = lib.mkOption {
          type = lib.types.str;
          default = "tailf0779.ts.net";
          description = "This tailnet's MagicDNS base domain — service VIPs hang under it.";
        };

        cloudflareAccountId = lib.mkOption {
          type = lib.types.str;
          default = "14613cda02f216f5620eca979a286eaf";
          description = "Cloudflare account id backing the R2 buckets (nimbus cache, restic repos).";
        };

        lanCidr = lib.mkOption {
          type = lib.types.str;
          default = "192.168.1.0/24";
          description = "Home LAN subnet the P3 nodes sit on and advertise as subnet routers.";
        };
      };
    };
}
