{ config, lib, pkgs, ... }:
let
  home = config.home.homeDirectory;
  darwinSockPath =
    "${home}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
  sockPath = "${home}/.1password/agent.sock";
  mkCompletion = shell:
    if shell == "zsh" then ''
      if command -v op >/dev/null; then
        eval "$(op completion ${shell})"; compdef _op op
      fi
    ''
    else if shell == "bash" then ''
      if command -v op >/dev/null; then
        source <(op completion ${shell})
      fi
    ''
    else if shell == "fish" then ''
      op completion fish | source
    ''
    else "";
in
{
  home.sessionVariables.SSH_AUTH_SOCK = sockPath;
  home.file.sock = lib.mkIf pkgs.stdenvNoCC.isDarwin {
    source = config.lib.file.mkOutOfStoreSymlink darwinSockPath;
    target = ".1password/agent.sock";
  };
  programs.bash.initExtra = lib.mkIf pkgs.stdenvNoCC.isDarwin (mkCompletion "bash");
  programs.zsh.initExtra = lib.mkIf pkgs.stdenvNoCC.isDarwin (mkCompletion "zsh");
  programs.ssh = {
    enable = true;
    extraConfig = ''
      IdentityAgent "${sockPath}"
    '';
  };
}
