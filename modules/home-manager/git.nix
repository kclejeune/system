{pkgs, ...}: {
  home.packages = builtins.attrValues {
    inherit
      (pkgs)
      github-cli
      git-subrepo
      git-get
      git-trim
      git-who
      git-my
      ;
  };
  programs.git = {
    enable = true;
    settings = {
      user.name = "Kennan LeJeune";
      credential.helper =
        if pkgs.stdenvNoCC.isDarwin
        then "osxkeychain"
        else "cache --timeout=1000000000";
      commit.verbose = true;
      fetch.prune = true;
      http.sslVerify = true;
      init.defaultBranch = "main";
      pull.rebase = true;
      push.followTags = true;
      push.autoSetupRemote = true;
      alias = {
        fix = "commit --amend --no-edit";
        ignore = "!gi() { curl -sL https://www.toptal.com/developers/gitignore/api/$@ ;}; gi";
        oops = "reset HEAD~1";
        sub = "submodule update --init --recursive";
      };
    };
    includes = [
      {
        path = "~/.gitconfig";
      }
    ];

    lfs.enable = true;
  };
}
