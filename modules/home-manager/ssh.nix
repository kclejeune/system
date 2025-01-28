{...}: {
  programs.ssh = {
    enable = true;
    includes = ["conf.d/*"];
    forwardAgent = true;
    matchBlocks = {
      "ssh.github.com" = {
        hostname = "ssh.github.com";
        user = "git";
        port = 443;
      };
    };
  };
}
