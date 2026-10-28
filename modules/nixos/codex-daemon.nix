_: {
  flake.nixosModules.codex-remote-control =
    { lib, pkgs, ... }:
    {
      # Run the same Codex package as the CLI; take over from a previously
      # detached Codex-managed daemon before binding its control socket.
      hm.systemd.user.services.codex-remote-control = {
        Unit.Description = "Codex app server with remote control";
        Service = {
          ExecStartPre = "${lib.getExe pkgs.codex} app-server daemon stop";
          ExecStart = "${lib.getExe pkgs.codex} app-server --remote-control --listen unix:// --managed-daemon";
          Restart = "on-failure";
          RestartSec = 10;
        };
        Install.WantedBy = [ "default.target" ];
      };
    };
}
