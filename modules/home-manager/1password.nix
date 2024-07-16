{
  config,
  lib,
  pkgs,
  ...
}: let
  home = config.home.homeDirectory;
  darwinSockPath = "${home}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
  sockPath = ".1password/agent.sock";
  aliases = {
    # gh = "op plugin run -- gh";
    # cachix = "op plugin run -- cachix";
    # brew = "op plugin run -- brew";
  };
in {
  home.sessionVariables = {
    SSH_AUTH_SOCK = "${home}/${sockPath}";
    OP_PLUGIN_ALIASES_SOURCED = 1;
  };

  home.file.sock = lib.mkIf pkgs.stdenvNoCC.isDarwin {
    source = config.lib.file.mkOutOfStoreSymlink darwinSockPath;
    target = sockPath;
  };
  programs.bash = {
    initExtra = lib.mkIf pkgs.stdenvNoCC.isDarwin ''
      if command -v op >/dev/null; then
        source <(op completion bash)
      fi
    '';
    shellAliases = aliases;
  };
  programs.fish = {
    interactiveShellInit = lib.mkIf pkgs.stdenvNoCC.isDarwin ''
      op completion fish | source
    '';
    shellAliases = aliases;
  };
  programs.zsh = {
    initExtra = lib.mkIf pkgs.stdenvNoCC.isDarwin ''
      if command -v op >/dev/null; then
        eval "$(op completion zsh)"; compdef _op op
      fi
    '';
    shellAliases = aliases;
  };
  programs.ssh = {
    enable = true;
    extraConfig = "IdentityAgent ~/${sockPath}";
  };
}
