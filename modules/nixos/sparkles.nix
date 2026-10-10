{ inputs, ... }:
{
  # Sparkles RDF / SPARQL server behind caddy-lan, signing in through Authelia.
  # The OIDC client is public (PKCE, no secret), so the auth config holds nothing
  # secret; model API keys are separate sops secrets.
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
      haiku = {
        provider = "anthropic";
        model = "claude-haiku-5-5";
      };
      sonnet = {
        provider = "anthropic";
        model = "claude-sonnet-5-5";
      };
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
        # These keys live under sparkles/ in the host's default sops file. The
        # server re-reads them for each request, so rotations need no restart.
        sops.secrets =
          lib.genAttrs
            [
              "sparkles/anthropic-api-key"
              "sparkles/openai-api-key"
            ]
            (_: {
              owner = config.services.sparkles.user;
              group = config.services.sparkles.group;
              mode = "0400";
            });

        # The declared model configuration. Server admins can change role lists,
        # budgets and model options at runtime (UI or `sparkles settings --global`);
        # the endpoints and key sources locked below stay with this file.
        services.sparkles.models.settings = {
          providers = {
            anthropic = {
              kind = "anthropic";
              endpoint = "https://api.anthropic.com";
              apiKey.secret = "anthropic";
              allowedModels = [
                haiku.model
                sonnet.model
              ];
              # Bound grounding below the models' full context windows.
              contextTokens = 200000;
              maxOutputTokens = 4096;
              requestTimeoutSecs = 90;
              models = {
                ${haiku.model} = {
                  # Stay within Haiku's cheaper prompt-length tier.
                  contextTokens = 100000;
                  pricing = {
                    inputPerMTok = 0.10;
                    outputPerMTok = 0.50;
                  };
                };
                ${sonnet.model}.pricing = {
                  inputPerMTok = 2.00;
                  outputPerMTok = 10.00;
                };
              };
            };
            # Available for explicit per-dataset role overrides; Claude handles
            # all default roles, so registering this provider makes no calls.
            openai = {
              kind = "openai";
              endpoint = "https://api.openai.com/v1";
              apiKey.secret = "openai";
            };
          };
          roles = {
            draft = [
              haiku
              sonnet
            ];
            repair = [ sonnet ];
            summarize = [
              haiku
              sonnet
            ];
            # Source-backed facts deserve stronger reasoning and room for spans.
            extract = [ (sonnet // { maxOutputTokens = 8192; }) ];
            explain = [
              haiku
              sonnet
            ];
            optimize = [ sonnet ];
          };
        };

        # Runtime changes persist and override the declared values, except for
        # locked fields. Keys stay on their sops files: a runtime key would be
        # stored unencrypted in the data directory.
        services.sparkles.settings.server.locked = [
          "models.providers.anthropic.endpoint"
          "models.providers.openai.endpoint"
          "secrets.anthropic"
          "secrets.openai"
        ];

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
          mcp.enable = true;
          models.secrets = {
            anthropic.file = config.sops.secrets."sparkles/anthropic-api-key".path;
            openai.file = config.sops.secrets."sparkles/openai-api-key".path;
          };
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
