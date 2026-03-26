{ ... }:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = [ "conf.d/*" ];
    matchBlocks = {
      "ssh.github.com" = {
        hostname = "ssh.github.com";
        user = "git";
        port = 443;
      };
      "*" = {
        forwardAgent = true;
        compression = false;
        serverAliveInterval = 30;
        serverAliveCountMax = 3;
        hashKnownHosts = false;
        userKnownHostsFile = "~/.ssh/known_hosts";
        controlMaster = "auto";
        controlPath = "~/.ssh/master-%r@%n:%p";
        controlPersist = "10m";
      };
    };
  };
}
