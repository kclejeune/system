{ config, lib, ... }:
let
  inherit (config.flake.lib.site) tailnetDomain;
  # pam_rssh sudo (deploy, nh --target-host) needs the forwarded agent. Root on
  # the far end can use it while connected, so only forward to our own servers.
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
