_: {
  flake.homeModules.weave =
    { pkgs, lib, ... }:
    {
      home.packages = [
        # `sem` collides with GNU parallel's semaphore wrapper (also called
        # `sem`); we want sem-cli to win since parallel users invoke `sem`
        # rarely and via the GNU parallel docs.
        (lib.hiPrio pkgs.sem-cli)
        pkgs.weave
      ];

      programs.git = {
        # Mirrors upstream `weave setup` (crates/weave-cli/src/commands/setup.rs).
        # Update when bumping the weave package if upstream adds/removes parsers.
        attributes = [
          # TypeScript / JavaScript
          "*.ts merge=weave"
          "*.tsx merge=weave"
          "*.js merge=weave"
          "*.mjs merge=weave"
          "*.cjs merge=weave"
          "*.jsx merge=weave"
          # Python / Go / Rust
          "*.py merge=weave"
          "*.go merge=weave"
          "*.rs merge=weave"
          # Java / C / C++
          "*.java merge=weave"
          "*.c merge=weave"
          "*.h merge=weave"
          "*.cpp merge=weave"
          "*.cc merge=weave"
          "*.cxx merge=weave"
          "*.hpp merge=weave"
          "*.hh merge=weave"
          "*.hxx merge=weave"
          # Ruby / C# / PHP / Swift / Elixir / Shell
          "*.rb merge=weave"
          "*.cs merge=weave"
          "*.php merge=weave"
          "*.swift merge=weave"
          "*.ex merge=weave"
          "*.exs merge=weave"
          "*.sh merge=weave"
          # Fortran
          "*.f90 merge=weave"
          "*.f95 merge=weave"
          "*.f03 merge=weave"
          "*.f08 merge=weave"
          # XML family
          "*.xml merge=weave"
          "*.plist merge=weave"
          "*.svg merge=weave"
          "*.csproj merge=weave"
          "*.fsproj merge=weave"
          "*.vbproj merge=weave"
          # Data / config
          "*.json merge=weave"
          "*.yaml merge=weave"
          "*.yml merge=weave"
          "*.toml merge=weave"
          # Docs
          "*.md merge=weave"
          # Scala family
          "*.scala merge=weave"
          "*.sc merge=weave"
          "*.sbt merge=weave"
          "*.kojo merge=weave"
          "*.mill merge=weave"
          # Dart
          "*.dart merge=weave"
        ];

        settings.merge.weave = {
          name = "weave semantic merge driver";
          driver = "weave-driver %O %A %B %L %P";
          recursive = "binary";
        };
      };
    };
}
