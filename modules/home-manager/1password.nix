{
  config,
  lib,
  pkgs,
  ...
}: let
  home = config.home.homeDirectory;
  darwinSockPath = "${home}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
  sockLink = ".1password/agent.sock";
in {
  home.sessionVariables = {
    OP_PLUGIN_ALIASES_SOURCED = 1;
  };

  home.file.sock = lib.mkIf pkgs.stdenvNoCC.isDarwin {
    source = config.lib.file.mkOutOfStoreSymlink darwinSockPath;
    target = sockLink;
  };

  programs.ssh = {
    enable = true;
    matchBlocks = {
      "*" = {
        identityAgent = "~/.1password/agent.sock";
      };
    };
  };

  programs.git = {
    signing = {
      signByDefault = true;
      key = null;
      format = "ssh";
      signer =
        if pkgs.stdenvNoCC.isDarwin
        then "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
        else "${pkgs._1password-gui}/share/1password/op-ssh-sign";
    };
  };
}
