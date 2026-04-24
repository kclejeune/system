_: {
  flake.homeModules.weave =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.weave ];

      programs.git = {
        attributes = [
          # TypeScript / JavaScript
          "*.ts merge=weave"
          "*.tsx merge=weave"
          "*.js merge=weave"
          "*.jsx merge=weave"
          "*.mjs merge=weave"
          "*.cjs merge=weave"
          "*.es6 merge=weave"
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
          # Kotlin
          "*.kt merge=weave"
          "*.kts merge=weave"
          # Fortran
          "*.f90 merge=weave"
          "*.f95 merge=weave"
          "*.f03 merge=weave"
          "*.f08 merge=weave"
          "*.f merge=weave"
          "*.for merge=weave"
          # HCL / Terraform
          "*.hcl merge=weave"
          "*.tf merge=weave"
          "*.tfvars merge=weave"
          # XML family
          "*.xml merge=weave"
          "*.plist merge=weave"
          "*.svg merge=weave"
          "*.csproj merge=weave"
          "*.fsproj merge=weave"
          "*.vbproj merge=weave"
          "*.xhtml merge=weave"
          "*.props merge=weave"
          "*.targets merge=weave"
          "*.nuspec merge=weave"
          "*.resx merge=weave"
          "*.xaml merge=weave"
          "*.axml merge=weave"
          # Data / config
          "*.json merge=weave"
          "*.yaml merge=weave"
          "*.yml merge=weave"
          "*.toml merge=weave"
          "*.csv merge=weave"
          "*.tsv merge=weave"
          # Docs
          "*.md merge=weave"
          "*.mdx merge=weave"
          # Web / templates
          "*.vue merge=weave"
          "*.svelte merge=weave"
          "*.erb merge=weave"
        ];

        settings.merge.weave = {
          name = "weave semantic merge driver";
          driver = "weave-driver %O %A %B %L %P";
          recursive = "binary";
        };
      };
    };
}
