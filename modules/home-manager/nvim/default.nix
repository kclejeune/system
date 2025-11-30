{
  config,
  pkgs,
  lib,
  ...
}: let
  extraPackages = with pkgs; [
    angular-language-server
    astro-language-server
    autotools-language-server
    awk-language-server
    basedpyright
    bash-language-server
    claude-code
    cmake-language-server
    cuelsp
    diagnostic-languageserver
    direnv
    docker-compose-language-service
    docker-language-server
    fzf
    git
    gopls
    jdt-language-server
    lua-language-server
    nil
    nixd
    protols
    ruby-lsp
    ruff
    svelte-language-server
    systemd-language-server
    tailwindcss-language-server
    terraform-ls
    texlab
    textlsp
    tooling-language-server
    tree-sitter
    typescript-language-server
    vim-language-server
    vscode-langservers-extracted
    vue-language-server
    yaml-language-server
    zls
  ];
  lazy-nix-helper-nvim = pkgs.vimUtils.buildVimPlugin {
    name = "lazy-nix-helper.nvim";
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
    name = "direnv.nvim";
    src = pkgs.fetchFromGitHub {
      owner = "NotAShelf";
      repo = "direnv.nvim";
      rev = "4dfc8758a1deab45e37b7f3661e0fd3759d85788";
      sha256 = "sha256-KqO8uDbVy4sVVZ6mHikuO+SWCzWr97ZuFRC8npOPJIE=";
    };
    meta.homepage = "https://github.com/NotAShelf/direnv.nvim";
  };
  sanitizePluginName = input: let
    name = lib.strings.getName input;
    vimplugin_removed = lib.strings.removePrefix "vimplugin-" name;
    luajit_removed = lib.strings.removePrefix "luajit2.1-" vimplugin_removed;
    lua5_1_removed = lib.strings.removePrefix "lua5.1-" luajit_removed;
    result = lib.strings.removeSuffix "-scm" lua5_1_removed;
  in
    result;

  pluginList = plugins:
    lib.strings.concatMapStrings (
      plugin: "  [\"${sanitizePluginName plugin.name}\"] = \"${plugin.outPath}\",\n"
    )
    plugins;
in {
  home.packages = extraPackages;
  xdg.configFile = {
    "nvim/lua" = {
      source = ./lua;
      recursive = true;
    };
    "nvim/lsp" = {
      source = ./lsp;
      recursive = true;
    };
  };

  programs.neovim = {
    inherit extraPackages;
    enable = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    # nvim plugin providers
    withNodeJs = true;
    withRuby = true;
    withPython3 = true;

    # share vim plugins since nothing is specific to nvim
    plugins = lib.attrValues {
      inherit lazy-nix-helper-nvim claudecode-nvim direnv-nvim;
      inherit
        (pkgs.vimPlugins)
        # basics
        comment-nvim
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
        nvim-treesitter-refactor
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
        # blink-cmp-env
        blink-cmp-conventional-commits
        tiny-inline-diagnostic-nvim
        plenary-nvim
        snacks-nvim
        which-key-nvim
        yazi-nvim
        ;

      inherit (pkgs.stable.vimPlugins) lualine-nvim;
      nvim-treesitter = pkgs.vimPlugins.nvim-treesitter.withAllGrammars;
    };

    extraLuaConfig = lib.mkBefore ''
      local plugins = {
      ${pluginList config.programs.neovim.plugins}
      }
      local lazy_nix_helper_path = "${lazy-nix-helper-nvim}"

      ${builtins.readFile ./lua/init.lua}
    '';
  };
}
