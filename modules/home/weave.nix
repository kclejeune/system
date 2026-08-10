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
        # TypeScript / JavaScript
        "*.ts"
        "*.tsx"
        "*.js"
        "*.mjs"
        "*.cjs"
        "*.jsx"
        # Python / Go / Rust
        "*.py"
        "*.go"
        "*.rs"
        # Java / C / C++
        "*.java"
        "*.c"
        "*.h"
        "*.cpp"
        "*.cc"
        "*.cxx"
        "*.hpp"
        "*.hh"
        "*.hxx"
        # Ruby / C# / PHP / Swift / Elixir / Shell
        "*.rb"
        "*.cs"
        "*.php"
        "*.swift"
        "*.ex"
        "*.exs"
        "*.sh"
        # Fortran
        "*.f90"
        "*.f95"
        "*.f03"
        "*.f08"
        # XML family
        "*.xml"
        "*.plist"
        "*.svg"
        "*.csproj"
        "*.fsproj"
        "*.vbproj"
        # Data / config
        "*.json"
        "*.yaml"
        "*.yml"
        "*.toml"
        # Docs
        "*.md"
        # Scala family
        "*.scala"
        "*.sc"
        "*.sbt"
        "*.kojo"
        "*.mill"
        # Dart
        "*.dart"
      ];

      # Opt-in attributes file: NOT `programs.git.attributes` (that writes
      # ~/.config/git/attributes, which git reads unconditionally and would make
      # weave the default merge driver everywhere). Pointed at explicitly by the
      # `git weave` alias below via `-c core.attributesFile=…`.
      #
      # core.attributesFile sits *below* in-tree `.gitattributes` and
      # `$GIT_DIR/info/attributes` in git's precedence order, so a repo that
      # configures its own merge drivers still wins.
      weaveAttributes = "${config.xdg.configHome}/git/attributes-weave";
    in
    {
      home.packages = [
        # `sem` collides with GNU parallel's semaphore wrapper (also called
        # `sem`); we want sem-cli to win since parallel users invoke `sem`
        # rarely and via the GNU parallel docs.
        (lib.hiPrio pkgs.sem-cli)
        pkgs.weave
      ];

      xdg.configFile."git/attributes-weave".text =
        lib.concatMapStringsSep "\n" (pat: "${pat} merge=weave") supportedPatterns + "\n";

      programs.git.settings = {
        # Registering the driver is inert on its own — git only invokes it for
        # paths whose `merge` attribute names it. A repo can opt in permanently
        # with `weave setup --local`, or per-command via the alias below.
        merge.weave = {
          name = "weave semantic merge driver";
          driver = "${lib.getExe' pkgs.weave "weave-driver"} %O %A %B %L %P";
          recursive = "binary";
        };

        # Passthrough wrapper: prefix any git command that runs a merge to get
        # entity-level merging for supported file types, just this once.
        #   git weave merge feature
        #   git weave rebase main
        #   git weave cherry-pick abc123
        #   git weave stash pop
        alias.weave = "!f() { git -c core.attributesFile='${weaveAttributes}' \"$@\"; }; f";
      };
    };
}
