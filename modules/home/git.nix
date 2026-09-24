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
          # user.name / user.email come from the identity module — see
          # modules/shared/identity.nix + profiles/personal.nix.
          # GitHub creds come from gh's token store instead of a years-long
          # in-memory cache; the empty entry resets the generic helper there.
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
          # Structural diffs on demand: `git difftool` (or `git dt`). Wired by
          # hand rather than via `programs.difftastic.git.enable` because that
          # option trips home-manager's assertion against delta's git
          # integration even in difftool-only mode. Deliberately NOT
          # `diff.external` — that would replace `git diff` output everywhere
          # and make it unparseable by grep/patch tooling, silently and with
          # exit 0. delta stays the pager (see modules/home/default.nix).
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
