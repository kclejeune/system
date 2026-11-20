_: {
  flake.homeModules.t3code-service =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux;
      desktop = config.desktop.enable;
      command = [
        (lib.getExe pkgs.llm-agents.t3code)
        "serve"
        "--host"
        "127.0.0.1"
        "--port"
        (if desktop then "43773" else "3773")
      ]
      # The desktop's built-in backend has exclusive access to its own data directory.
      ++ lib.optionals desktop [
        "--base-dir"
        "${config.home.homeDirectory}/.t3-worker"
      ];
      path = lib.concatStringsSep ":" (
        [
          "${config.home.profileDirectory}/bin"
          "/run/current-system/sw/bin"
        ]
        ++ lib.optionals isDarwin [
          "/opt/homebrew/bin"
          "/usr/bin"
          "/bin"
          "/usr/sbin"
          "/sbin"
        ]
      );
    in
    lib.mkMerge [
      (lib.mkIf isLinux {
        systemd.user.services.t3code-worker = {
          Unit.Description = "T3 Code headless server";
          Service = {
            ExecStart = lib.escapeShellArgs command;
            Environment = "PATH=${path}";
            Restart = "on-failure";
            RestartSec = 10;
          };
          Install.WantedBy = [ "default.target" ];
        };
      })
      (lib.mkIf isDarwin {
        launchd.agents.t3code-worker = {
          enable = true;
          domain = "gui";
          config = {
            ProgramArguments = command;
            WorkingDirectory = config.home.homeDirectory;
            EnvironmentVariables.PATH = path;
            KeepAlive = true;
            ThrottleInterval = 10;
          };
        };
      })
    ];
}
