{
  config,
  pkgs,
  lib,
  ...
}: let
  lsp-servers = with pkgs; [
    angular-language-server
    ansible-language-server
    astro-language-server
    autotools-language-server
    awk-language-server
    basedpyright
    bash-language-server
    cmake-language-server
    cuelsp
    diagnostic-languageserver
    docker-compose-language-service
    docker-language-server
    fzf
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
  direnv-nvim = pkgs.vimUtils.buildVimPlugin {
    name = "direnv.nvim";
    src = pkgs.fetchFromGitHub {
      owner = "NotAShelf";
      repo = "direnv.nvim";
      rev = "4dfc8758a1deab45e37b7f3661e0fd3759d85788";
      sha256 = "sha256-ZCViqnA+VoEOG+Xr+aJNlfRKCjxJm5y78HRXax3o8UY=";
    };
    meta.homepage = "https://github.com/NotAShelf/direnv.nvim";
  };
  ranger-nvim = pkgs.vimUtils.buildVimPlugin {
    name = "ranger.nvim";
    src = pkgs.fetchFromGitHub {
      owner = "kelly-lin";
      repo = "ranger.nvim";
      rev = "fd2cc999f3ef88f7cdcbcad5f26000c52b16c489";
      sha256 = "sha256-ZCViqnA+VoEOG+Xr+aJNlfRKCjxJm5y78HRXax3o8UY=";
    };
    meta.homepage = "https://github.com/kelly-lin/ranger.nvim";
  };
  auto-dark-mode-nvim = pkgs.vimUtils.buildVimPlugin {
    pname = "auto-dark-mode.nvim";
    version = "v0.1.0";
    src = pkgs.fetchFromGitHub {
      owner = "f-person";
      repo = "auto-dark-mode.nvim";
      rev = "c31de126963ffe9403901b4b0990dde0e6999cc6";
      sha256 = "sha256-ZCViqnA+VoEOG+Xr+aJNlfRKCjxJm5y78HRXax3o8UY=";
    };
    meta.homepage = "https://github.com/f-person/auto-dark-mode.nvim";
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
  home.packages = lsp-servers;
  xdg.configFile."nvim/lua" = {
    source = ./lua;
    recursive = true;
  };
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    # nvim plugin providers
    withNodeJs = true;
    withRuby = true;
    withPython3 = true;
    extraPackages = [pkgs.git] ++ lsp-servers;

    # share vim plugins since nothing is specific to nvim
    plugins = with pkgs.vimPlugins; [
      # basics
      vim-sensible
      vim-fugitive
      vim-sandwich
      vim-commentary
      vim-nix
      nvim-autopairs

      # configurable plugins
      lazy-nix-helper-nvim
      lazy-nvim
      guess-indent-nvim
      fzf-lua
      vimtex
      nvim-lspconfig
      indent-blankline-nvim

      nvim-treesitter.withAllGrammars
      nvim-treesitter-refactor
      nvim-treesitter-textobjects
      nvim-treesitter-context
      nvim-web-devicons
      nvim-tree-lua
      mason-nvim
      mason-lspconfig-nvim
      lualine-nvim
      onedark-nvim
      direnv-nvim
      ranger-nvim
      auto-dark-mode-nvim
    ];

    extraLuaConfig = lib.mkBefore ''
      local plugins = {
      ${pluginList config.programs.neovim.plugins}
      }
      local lazy_nix_helper_path = "${lazy-nix-helper-nvim}"

      ${builtins.readFile ./lua/init.lua}
    '';
  };
}
