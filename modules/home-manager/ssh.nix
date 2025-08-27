{...}: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = ["conf.d/*"];
    matchBlocks = {
      "ssh.github.com" = {
        hostname = "ssh.github.com";
        user = "git";
        port = 443;
      };
      "*" = {
        forwardAgent = true;
      };
    };
  };
}
