_: {
  flake.homeModules.weave =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      # Mirrors upstream `weave setup` (crates/weave-cli/src/commands/setup.rs).
      # Update when bumping the weave package if upstream adds/removes parsers.
      supportedPatterns = [
        "*.ts"
        "*.tsx"
        "*.js"
        "*.mjs"
        "*.cjs"
        "*.jsx"
        "*.py"
        "*.go"
        "*.rs"
        "*.java"
        "*.c"
        "*.h"
        "*.cpp"
        "*.cc"
        "*.cxx"
        "*.hpp"
        "*.hh"
        "*.hxx"
        "*.rb"
        "*.cs"
        "*.php"
        "*.swift"
        "*.ex"
        "*.exs"
        "*.sh"
        "*.f90"
        "*.f95"
        "*.f03"
        "*.f08"
        "*.xml"
        "*.plist"
        "*.svg"
        "*.csproj"
        "*.fsproj"
        "*.vbproj"
        "*.json"
        "*.yaml"
        "*.yml"
        "*.toml"
        "*.md"
        "*.scala"
        "*.sc"
        "*.sbt"
        "*.kojo"
        "*.mill"
        "*.dart"
      ];

      # Opt-in only: programs.git.attributes would make weave the merge driver
      # everywhere. core.attributesFile ranks below in-repo attributes, so a repo's
      # own drivers still win.
      weaveAttributes = "${config.xdg.configHome}/git/attributes-weave";
    in
    {
      home.packages = [
        # sem-cli's `sem` beats GNU parallel's rarely used `sem`.
        (lib.hiPrio pkgs.sem-cli)
        pkgs.weave
      ];

      xdg.configFile."git/attributes-weave".text =
        lib.concatMapStringsSep "\n" (pat: "${pat} merge=weave") supportedPatterns + "\n";

      programs.git.settings = {
        # Inert until a path's `merge` attribute names it (`weave setup --local` or the alias).
        merge.weave = {
          name = "weave semantic merge driver";
          driver = "${lib.getExe' pkgs.weave "weave-driver"} %O %A %B %L %P";
          recursive = "binary";
        };

        # Prefix any merging command (merge, rebase, cherry-pick, stash pop) to use weave
        # just that once.
        alias.weave = "!f() { git -c core.attributesFile='${weaveAttributes}' \"$@\"; }; f";
      };
    };
}
