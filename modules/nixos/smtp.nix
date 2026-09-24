_: {
  # One outbound-mail account per host. Consumers read config.smtp.{host,port}
  # and sops smtp/{username,password}; add an `owner` if reading by path.
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
