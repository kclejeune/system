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
      separateDesktopState = config.desktop.enable && !config.services.t3code-worker.useDefaultDataDir;
      command = [
        (lib.getExe pkgs.llm-agents.t3code)
        "serve"
        "--host"
        "127.0.0.1"
        "--port"
        (if separateDesktopState then "43773" else "3773")
      ]
      # The desktop's built-in backend has exclusive access to its own data directory.
      ++ lib.optionals separateDesktopState [
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
    {
      options.services.t3code-worker.useDefaultDataDir = lib.mkEnableOption ''
        the worker owning the default T3 Code data directory on a desktop host.
        Turn off Local environment in the desktop app and pair it with the worker
      '';

      config = lib.mkMerge [
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
    };
}
