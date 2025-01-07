{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) types mkOption mkIf;
  cfg = config.services.ollama;
in {
  options = {
    services.ollama = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable the Ollama launchd service.";
      };

      package = mkOption {
        type = types.path;
        default = pkgs.ollama;
        description = "ollama package definition to install";
      };

      hostname = mkOption {
        type = types.nullOr types.str;
        default = "localhost";
        example = "localhost";
        description = ''
          the hostname for serving the Ollama API
        '';
      };

      port = mkOption {
        type = types.nullOr types.int;
        default = 11434;
        example = 11434;
        description = ''
          the port for exposing the Ollama API
        '';
      };
    };
  };

  config = mkIf (cfg.enable) {
    environment.systemPackages = [cfg.package];
    launchd.user.agents.ollama = {
      path = [cfg.package];
      command = "${cfg.package}/bin/ollama serve";
      environment = {
        OLLAMA_HOST = "${cfg.hostname}:${toString cfg.port}";
      };
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        ProcessType = "Background";
      };
    };
  };
}
