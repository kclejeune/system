_: {
  flake.homeModules.nvim =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      # Kept small for headless hosts; vim.lsp.enable skips missing servers, so the
      # desktop set below can be absent.
      coreExtraPackages = builtins.attrValues {
        inherit (pkgs)
          bash-language-server
          direnv
          fzf
          git
          nil
          nixd
          systemd-language-server
          tree-sitter
          yaml-language-server
          ;
      };

      # Heavy toolchains that only feed LSPs; skipping them saves ~5 GiB on servers.
      desktopExtraPackages = builtins.attrValues {
        inherit (pkgs)
          angular-language-server
          astro-language-server
          autotools-language-server
          awk-language-server
          basedpyright
          clang-tools
          clang
          claude-code
          cmake-language-server
          cuelsp
          diagnostic-languageserver
          docker-compose-language-service
          docker-language-server
          gopls
          jdt-language-server
          lua-language-server
          opencode
          oxlint
          protols # codespell:ignore
          ruby-lsp
          ruff
          rustup
          svelte-language-server
          tailwindcss-language-server
          terraform-ls
          texlab
          textlsp
          tooling-language-server
          ty
          typescript-language-server
          vim-language-server
          vscode-langservers-extracted
          # vue-language-server
          zls
          ;
      };
      lazy-nix-helper-nvim = pkgs.vimUtils.buildVimPlugin {
        pname = "lazy-nix-helper.nvim";
        version = "0.7.0";
        src = pkgs.fetchFromGitHub {
          owner = "b-src";
          repo = "lazy-nix-helper.nvim";
          rev = "v0.7.0";
          sha256 = "sha256-4DyuBMp83vM344YabL2SklQCg6xD7xGF5CvQP2q+W7A=";
        };
      };
      claudecode-nvim = pkgs.vimUtils.buildVimPlugin {
        pname = "claudecode.nvim";
        version = "2025-10-19";
        src = pkgs.fetchFromGitHub {
          owner = "coder";
          repo = "claudecode.nvim";
          rev = "1552086ebcce9f4a2ea3b9793018a884d6b60169";
          sha256 = "sha256-XYmf1RQ2bVK6spINZW4rg6OQQ5CWWcR0Tw4QX8ZDjgs=";
        };
        meta.homepage = "https://github.com/coder/claudecode.nvim";
      };
      direnv-nvim = pkgs.vimUtils.buildVimPlugin {
        pname = "direnv.nvim";
        # No "unstable-" prefix: parseDrvName folds it into the name, so
        # lazy-nix-helper misses the plugin and lazy clones it from GitHub.
        version = "2025-04-28";
        src = pkgs.fetchFromGitHub {
          owner = "NotAShelf";
          repo = "direnv.nvim";
          rev = "4dfc8758a1deab45e37b7f3661e0fd3759d85788";
          sha256 = "sha256-KqO8uDbVy4sVVZ6mHikuO+SWCzWr97ZuFRC8npOPJIE=";
        };
        meta.homepage = "https://github.com/NotAShelf/direnv.nvim";
      };
      sanitizePluginName =
        input:
        let
          name = lib.strings.getName input;
          vimplugin_removed = lib.strings.removePrefix "vimplugin-" name;
          luajit_removed = lib.strings.removePrefix "luajit2.1-" vimplugin_removed;
          lua5_1_removed = lib.strings.removePrefix "lua5.1-" luajit_removed;
          result = lib.strings.removeSuffix "-scm" lua5_1_removed;
        in
        result;

      # Not withAllGrammars: each grammar has an allowSubstitutes=false queries drv
      # that CI rebuilds on every fresh store (~310 of them).
      nvim-treesitter = pkgs.vimPlugins.nvim-treesitter.withPlugins (
        p:
        builtins.attrValues {
          inherit (p)
            angular
            astro
            awk
            bash
            bibtex
            c
            caddy
            cmake
            comment
            cpp
            css
            csv
            cue
            dhall
            diff
            dockerfile
            doxygen
            earthfile
            editorconfig
            eex
            elixir
            erlang
            fennel
            git_config
            git_rebase
            gitattributes
            gitcommit
            gitignore
            go
            gomod
            gosum
            gotmpl
            gowork
            graphql
            groovy
            hcl
            heex
            helm
            html
            http
            hyprlang
            ini
            java
            javadoc
            javascript
            jinja
            jinja_inline
            jq
            jsdoc
            json
            json5
            just
            kotlin
            latex
            llvm
            lua
            luadoc
            luap
            make
            markdown
            markdown_inline
            mermaid
            meson
            nginx
            nickel
            ninja
            nix
            passwd
            pem
            perl
            printf
            promql
            proto
            python
            query
            regex
            requirements
            ruby
            rust
            scss
            sparql
            sql
            ssh_config
            svelte
            tera
            terraform
            toml
            tsx
            typescript
            typst
            udev
            vim
            vimdoc
            vue
            xml
            yaml
            zig
            zsh
            ;
        }
      );
      nvim-treesitter-grammars = pkgs.symlinkJoin {
        name = "nvim-treesitter-grammars";
        paths = nvim-treesitter.dependencies;
      };
      pluginList =
        plugins:
        lib.strings.concatMapStrings (
          plugin: "  [\"${sanitizePluginName plugin.name}\"] = \"${plugin.outPath}\",\n"
        ) plugins;

      extraPackages = coreExtraPackages ++ lib.optionals config.desktop.enable desktopExtraPackages;
    in
    {
      # On PATH too, so the tools work outside the nvim wrapper.
      home.packages = extraPackages;
      xdg.configFile = {
        "nvim/lua" = {
          source = ./assets/nvim/lua;
          recursive = true;
        };
        "nvim/lsp" = {
          source = ./assets/nvim/lsp;
          recursive = true;
        };
        "nvim/parser" = {
          source = "${nvim-treesitter-grammars}/parser";
          recursive = true;
        };
        # The grammar drvs ship only parsers and we bypass :TSInstall, so link the
        # queries ourselves; without them buffers render unhighlighted.
        "nvim/queries" = {
          source = "${nvim-treesitter}/runtime/queries";
          recursive = true;
        };
      };

      programs.neovim = {
        inherit extraPackages;
        enable = true;
        viAlias = true;
        vimAlias = true;
        vimdiffAlias = true;
        defaultEditor = true;

        withNodeJs = true;
        withRuby = true;
        withPython3 = true;

        # share vim plugins since nothing is specific to nvim
        plugins = lib.attrValues {
          inherit
            lazy-nix-helper-nvim
            claudecode-nvim
            direnv-nvim
            nvim-treesitter
            ;
          inherit (pkgs.vimPlugins)
            conform-nvim
            mini-nvim
            nvim-autopairs
            vim-nix
            lazy-nvim
            guess-indent-nvim
            fzf-lua
            vimtex
            indent-blankline-nvim
            nvim-lspconfig
            # queries only — the textobject engine is mini.ai
            nvim-treesitter-textobjects
            nvim-treesitter-context
            mason-nvim
            mason-lspconfig-nvim
            onedark-nvim
            friendly-snippets
            lazygit-nvim
            lazydev-nvim
            blink-cmp
            blink-cmp-env
            blink-cmp-conventional-commits
            tiny-inline-diagnostic-nvim
            plenary-nvim
            yazi-nvim
            ;
        };

        initLua = lib.mkBefore ''
          local plugins = {
          ${pluginList config.programs.neovim.plugins}
          }
          local lazy_nix_helper_path = "${lazy-nix-helper-nvim}"

          ${builtins.readFile ./assets/nvim/lua/init.lua}
        '';
      };
    };
}
