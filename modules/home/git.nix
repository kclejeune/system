{ config, ... }:
let
  flakeCfg = config;
in
{
  flake.homeModules.git =
    { pkgs, lib, ... }:
    {
      imports = [ flakeCfg.flake.homeModules.weave ];

      home.packages = builtins.attrValues {
        inherit (pkgs)
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
          # user.name/email come from the identity module. GitHub creds come from gh;
          # the empty entry resets inherited helpers.
          credential = {
            helper = if pkgs.stdenv.hostPlatform.isDarwin then "osxkeychain" else "cache --timeout=3600";
            "https://github.com".helper = [
              ""
              "!${lib.getExe pkgs.github-cli} auth git-credential"
            ];
            "https://gist.github.com".helper = [
              ""
              "!${lib.getExe pkgs.github-cli} auth git-credential"
            ];
          };
          commit.verbose = true;
          fetch.prune = true;
          http.sslVerify = true;
          init.defaultBranch = "main";
          pull.rebase = true;
          push.followTags = true;
          push.autoSetupRemote = true;
          # Wired by hand; see modules/home/default.nix for why.
          diff.tool = "difftastic";
          difftool.prompt = false;
          difftool.difftastic.cmd = "${lib.getExe pkgs.difftastic} $LOCAL $REMOTE";
          alias = {
            dt = "difftool";
            fix = "commit --amend --no-edit";
            ignore = "!gi() { curl -sL https://www.toptal.com/developers/gitignore/api/$@ ;}; gi";
            oops = "reset HEAD~1";
            sub = "submodule update --init --recursive";
          };
        };
        includes = [ { path = "~/.gitconfig"; } ];

        lfs.enable = true;
      };
    };
}
