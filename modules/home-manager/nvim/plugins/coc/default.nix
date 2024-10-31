{
  config,
  pkgs,
  ...
}: {
  # link coc-settings to the right location
  xdg.configFile."nvim/coc-settings.json".source = ./coc-settings.json;

  programs.neovim = {
    extraPackages = with pkgs; [
      rubyPackages.solargraph
      pyright
      nixd
      fzf
    ];
    plugins = with pkgs.vimPlugins; [
      (config.lib.vimUtils.pluginWithCfg {
        plugin = coc-nvim;
        file = ./coc-nvim.vim;
      })
      coc-css
      coc-eslint
      coc-fzf
      coc-git
      coc-go
      coc-html
      coc-java
      coc-json
      coc-lua
      coc-pairs
      coc-prettier
      coc-pyright
      coc-r-lsp
      coc-rls
      coc-smartf
      coc-snippets
      coc-solargraph
      coc-tsserver
      coc-vetur
      coc-vimlsp
      coc-vimtex
      coc-yaml
    ];
  };
}
