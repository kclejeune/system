{ config, lib, pkgs, ... }:

with lib;

let cfg = config.services.syncthing;
in {
  options = {
    services.syncthing = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable the Syncthing service.";
      };

      homeDir = mkOption {
        type = types.nullOr types.path;
        default = "~";
        example = "/Users/kclejeune";
        description = ''
          the base location for the syncthing folder
        '';
      };

      logDir = mkOption {
        type = types.nullOr types.path;
        default = "~/Library/Logs";
        example = "~/Library/Logs";
        description = ''
          The logfile to use for the Syncthing service.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.syncthing ];
    launchd.user.agents.syncthing = {
      command = "${pkgs.syncthing}/bin/syncthing";
      serviceConfig = {
        Label = "net.syncthing.syncthing";
        KeepAlive = true;
        LowPriorityIO = true;
        ProcessType = "Background";
        StandardOutPath = "${cfg.logDir}/Syncthing.log";
        StandardErrorPath = "${cfg.logDir}/Syncthing-Errors.log";
        EnvironmentVariables = {
          NIX_PATH = "nixpkgs=" + toString pkgs.path;
          STNORESTART = "1";
        };
      };
    };
  };
}
