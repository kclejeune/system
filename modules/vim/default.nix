{ config, pkgs, lib, ... }:
let
  readVimSection = file: builtins.readFile (./. + "/${file}.vim");
  pluginWithCfg = plugin: {
    inherit plugin;
    config = readVimSection "plugins/${plugin.pname}";
  };
  # For plugins configured with lua
  wrapLuaConfig = luaConfig: ''
    lua<<EOF
    ${luaConfig}
    EOF
  '';
  readLuaSection = file:
    wrapLuaConfig (builtins.readFile (./. + "/${file}.lua"));
  pluginWithLua = plugin: {
    inherit plugin;
    config = readLuaSection "plugins/${plugin.pname}";
  };
  vimPlugins = with pkgs.vimPlugins;
    with pkgs.tree-sitter.builtGrammars; [
      # basics
      vim-sensible
      vim-fugitive
      vim-surround
      vim-commentary
      vim-sneak
      vim-closetag
      vim-nix
      vim-polyglot
      kotlin-vim

      # vim addon utilities
      direnv-vim
      ranger-vim
      (pluginWithCfg fzf-vim)

      # IDE-esque utilities
      (pluginWithCfg coc-nvim)
      (pluginWithCfg vimtex)
      coc-css
      coc-html
      coc-eslint
      # coc-tslint
      coc-json
      coc-prettier
      coc-tsserver
      coc-yaml
      coc-snippets
      coc-pairs
      coc-git
      # coc-pyright
      coc-java

      # new neovim stuff
      (pluginWithLua nvim-treesitter)
      (pluginWithLua nvim-treesitter-textobjects)

      (pluginWithLua nvim-lspconfig) # Config for neovim's built-in LSP client
      (pluginWithLua lspsaga-nvim)
      (pluginWithCfg completion-nvim) # Autocompletion
      completion-buffers
      completion-treesitter

      # theming
      awesome-vim-colorschemes
    ];
in {
  programs.neovim = {
    enable = true;
    package = pkgs.neovim-nightly;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    # nvim plugin providers
    withNodeJs = true;
    withRuby = true;
    withPython = true;
    withPython3 = true;

    # share vim plugins since nothing is specific to nvim
    plugins = vimPlugins;
    extraPackages = with pkgs; [
      texlab # latex
      rnix-lsp # nix
      nodePackages.pyright # python
      nodePackages.vim-language-server # vim
      # sumneko-lua-language-server # lua
      nodePackages.yaml-language-server # yaml
    ];

    extraConfig = ''
      ${readVimSection "settings"}
      ${wrapLuaConfig "require'lspconfig'.texlab.setup{}"}
      ${wrapLuaConfig "require'lspconfig'.rnix.setup{}"}
      ${wrapLuaConfig "require'lspconfig'.pyright.setup{}"}
    '';
  };

  # Treesitter grammars
  # shamelessly stolen from @i077
  # https://github.com/i077/system/blob/master/modules/editors/neovim/default.nix
  # currently broken on macOS big sur
  # xdg.configFile = let
  #   # The languages for which I want to use tree-sitter
  #   languages = [
  #     "bash"
  #     "c"
  #     "cpp"
  #     "rust"
  #     "css"
  #     "go"
  #     "haskell"
  #     "html"
  #     "java"
  #     "javascript"
  #     "json"
  #     "lua"
  #     "nix"
  #     "python"
  #   ];
  #   # Map each language to its respective tree-sitter package
  #   grammarPkg = l:
  #     (pkgs.tree-sitter.builtGrammars.${"tree-sitter-" + l}.overrideAttrs
  #       (oldAttrs: rec {
  #         postPatch = ''
  #           for f in *.cc; do
  #             substituteInPlace $f --replace gcc cc
  #           done
  #         '';
  #       }));
  #   # Map each language to a name-value pair for xdg.configFile
  #   langToFile = lang:
  #     lib.nameValuePair "nvim/parser/${lang}.so" {
  #       source = "${grammarPkg lang}/parser";
  #     };
  #   # The final collection of name-value pairs
  #   files = map langToFile languages;
  # in builtins.listToAttrs files;
}
