{ inputs, ... }:
{
  # Sparkles RDF / SPARQL server behind caddy-lan, signing in through Authelia.
  # The OIDC client is public (PKCE, no secret), so the auth config holds nothing
  # secret and there is no sops entry; Authelia's redirect_uris are the allowlist.
  # Needs a UniFi Local DNS Record for the subdomain.
  flake.nixosModules.sparkles =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.services.sparklesLan;
      port = 3030;
      publicUrl = "https://${cfg.subdomain}.${config.services.caddyLan.baseDomain}";
      # Requires traceway-agent on the host.
      agent = config.services.traceway.agent;
    in
    {
      imports = [ inputs.sparkles.nixosModules.default ];

      options.services.sparklesLan = {
        enable = lib.mkEnableOption "the Sparkles SPARQL server fronted by caddy-lan";

        subdomain = lib.mkOption {
          type = lib.types.str;
          default = "sparkles";
          description = "caddy-lan subdomain; the OIDC redirect URI is built from it.";
        };

        datasets = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
          example = {
            wiki = { };
          };
          description = "Passed to services.sparkles.datasets; more can be created in the UI.";
        };

        adminGroup = lib.mkOption {
          type = lib.types.str;
          default = "lldap_admin";
          description = ''
            LDAP group whose members get server-admin. Every other Authelia login
            is refused by Sparkles (default deny), even though the Authelia
            client's policy lets any two-factor user through.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        # No secrets inside: a public client, and group -> role mappings.
        environment.etc."sparkles/auth.toml" = {
          user = config.services.sparkles.user;
          group = config.services.sparkles.group;
          mode = "0400";
          text = ''
            version = 1
            realm = "sparkles"

            [server]
            public_url = "${publicUrl}"

            [roles.admins]
            server = ["server-admin", "metrics"]

            [oidc]
            issuer = "https://auth.${config.site.domain}"
            client_id = "sparkles"
            scopes = ["openid", "profile", "email", "groups"]
            name_claim = "preferred_username"
            groups_claim = "groups"
            display_name = "Authelia"

            [external]
            allowed_groups = ["${cfg.adminGroup}"]
            [external.group_roles]
            "${cfg.adminGroup}" = ["admins"]
          '';
        };

        services.sparkles = {
          enable = true;
          # Loopback-only: caddy-lan is the sole ingress.
          listenAddress = "127.0.0.1";
          inherit port;
          inherit (cfg) datasets;
          auth.configFile = "/etc/sparkles/auth.toml";
          # caddy sets X-Forwarded-For to the real client, which the failed-login
          # budget is keyed on.
          extraArgs = [
            "--rate-limit-trusted-proxy"
            "127.0.0.1/32"
          ];

          otel = lib.mkIf agent.enable {
            enable = true;
            endpoint = agent.otlpEndpoint;
            protocol = "http/protobuf";
            logs = true;
            environment = {
              OTEL_SERVICE_NAME = "${config.networking.hostName}-sparkles";
              OTEL_RESOURCE_ATTRIBUTES = "deployment.environment.name=production";
            };
          };
        };

        services.caddyLan.proxies.${cfg.subdomain} = "127.0.0.1:${toString port}";
        # Sparkles traces its own requests with route templates; a Caddy span per
        # request would only add a path-named duplicate.
        services.caddyLan.selfTraced = lib.mkIf agent.enable [ cfg.subdomain ];

        # Logs already go over OTLP with trace ids; keep the journal copy local.
        services.traceway.agent.journal.excludeUnits = lib.mkIf agent.enable [ "sparkles.service" ];
      };
    };
}
