_: {
  # One outbound-mail account for every mailer on a host. Consumers read
  # config.smtp.{host,port} and the sops secrets smtp/{username,password}
  # (as a placeholder in a template, or by path for _FILE-style options —
  # add an `owner` on the secret from the consumer if it reads by path).
  flake.nixosModules.smtp =
    { lib, ... }:
    {
      options.smtp = {
        host = lib.mkOption {
          type = lib.types.str;
          description = "Submission host shared by every mailer on this host.";
        };
        port = lib.mkOption {
          type = lib.types.port;
          default = 587;
        };
      };

      config.sops.secrets = {
        "smtp/username" = { };
        "smtp/password" = { };
      };
    };
}
