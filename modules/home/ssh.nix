_: {
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
        "*" = {
          ForwardAgent = true;
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
