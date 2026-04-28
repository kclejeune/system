_: {
  flake.homeModules.nvim =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      # Always-on: LSPs and tools that make nvim usable on a headless host
      # (editing nix / yaml / shell / unit files), plus plugin infra used
      # by lazy-nix-helper / direnv-nvim / treesitter / blink. Missing
      # binaries are logged-and-skipped by `vim.lsp.enable`, so the gated
      # set below is safe to omit on gateway.
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

      # Desktop-only: heavy compilers / language toolchains pulled in only
      # to feed LSPs (clang, rustup, gopls, jdtls, ts-ls, basedpyright, ...).
      # Gated on `config.desktop.enable` — gateway sheds ~5 GiB of LSP
      # closure by skipping these.
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
          vue-language-server
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
        version = "unstable-2025-04-28";
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

      nvim-treesitter = pkgs.vimPlugins.nvim-treesitter.withAllGrammars;
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
      # Same list used for both home.packages (so the binaries land on
      # the user PATH) and programs.neovim.extraPackages (so the wrapped
      # nvim launcher sees them too even without a shell context).
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
      };

      programs.neovim = {
        inherit extraPackages;
        enable = true;
        viAlias = true;
        vimAlias = true;
        vimdiffAlias = true;
        defaultEditor = true;

        # nvim plugin providers
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
            # basics
            comment-nvim
            conform-nvim
            nvim-autopairs
            vim-fugitive
            vim-nix
            vim-sandwich
            vim-sensible
            # configurable plugins
            lazy-nvim
            guess-indent-nvim
            fzf-lua
            vimtex
            nvim-lspconfig
            indent-blankline-nvim
            nvim-treesitter-textobjects
            nvim-treesitter-context
            nvim-web-devicons
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
            snacks-nvim
            which-key-nvim
            yazi-nvim
            ;

          inherit (pkgs.stable.vimPlugins) lualine-nvim;
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
