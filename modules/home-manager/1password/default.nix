{ config, lib, pkgs, ... }:
let
  home = config.home.homeDirectory;
  darwinSockPath =
    "${home}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
  sockPath = "${home}/.1password/agent.sock";
in
{
  home.sessionVariables.SSH_AUTH_SOCK = sockPath;
  home.file.sock = lib.mkIf pkgs.stdenvNoCC.isDarwin {
    source = config.lib.file.mkOutOfStoreSymlink darwinSockPath;
    target = ".1password/agent.sock";
  };
  programs.bash.initExtra = lib.mkIf pkgs.stdenvNoCC.isDarwin ''
    if command -v op > /dev/null 2&>1; then
      source <(op completion bash)
    fi
  '';
  programs.zsh.initExtra = lib.mkIf pkgs.stdenvNoCC.isDarwin ''
    if command -v op > /dev/null 2&>1; then
      eval "$(op completion zsh)"; compdef _op op
    fi
  '';
  programs.ssh = {
    enable = true;
    extraConfig = ''
      IdentityAgent "${sockPath}"
    '';
  };
}
