{ config, lib, pkgs, ... }: {
  home.packages = [ pkgs.github-cli ];
  programs.git = {
    userName = "Kennan LeJeune";
    extraConfig = {
      credential.helper =
        if pkgs.stdenvNoCC.isDarwin then
          "osxkeychain"
        else
          "cache --timeout=1000000000";
      http.sslVerify = true;
      pull.rebase = false;
    };
    aliases = {
      commit = "commit --verbose";
      fetch = "fetch --verbose";
      fix = "commit --amend --no-edit";
      oops = "reset HEAD~1";
      pull = "pull --verbose";
      push = "push --verbose";
    };
    delta.enable = true;
  };
}
