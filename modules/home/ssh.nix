{ config, lib, ... }:
let
  inherit (config.flake.lib.site) tailnetDomain;
  # Servers authenticate sudo with pam_rssh against the forwarded agent,
  # which `deploy` / `nh --target-host` rely on. Root on a host can use a
  # forwarded agent while you're connected, so forward only to our own
  # servers, never to arbitrary hosts.
  agentForwardHosts = [
    "gateway"
    "haven"
    "forge"
    "vault"
    "atlas"
  ];
  agentForwardPattern = lib.concatStringsSep " " (
    agentForwardHosts ++ map (h: "${h}.${tailnetDomain}") agentForwardHosts
  );
in
{
  flake.homeModules.ssh = _: {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      includes = [ "conf.d/*" ];
      settings = {
        "ssh.github.com" = {
          HostName = "ssh.github.com";
          User = "git";
          Port = 443;
        };
        ${agentForwardPattern}.ForwardAgent = true;
        "*" = {
          ForwardAgent = false;
          Compression = false;
          ServerAliveInterval = 30;
          ServerAliveCountMax = 3;
          HashKnownHosts = false;
          UserKnownHostsFile = "~/.ssh/known_hosts";
          ControlMaster = "auto";
          ControlPath = "~/.ssh/master-%C";
          ControlPersist = "10m";
        };
      };
    };
  };
}
