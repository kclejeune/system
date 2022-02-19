{ config, pkgs, lib, ... }: {
  # link coc-settings to the right location
  xdg.configFile."nvim/coc-settings.json".source = ./coc-settings.json;

  programs.neovim =
    let inherit (lib.vimUtils ./.) pluginWithCfg;
    in
    {
      extraPackages = with pkgs; [
        rubyPackages.solargraph
        nodePackages.pyright
        rnix-lsp
        fzf
      ];
      plugins = with pkgs.vimPlugins; [
        (pluginWithCfg {
          plugin = coc-nvim;
          file = "coc-nvim";
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
        coc-pyright # python
        coc-r-lsp
        coc-rls
        coc-smartf
        coc-snippets
        coc-solargraph
        coc-tslint
        coc-tsserver # js/ts
        coc-vetur # vuejs
        coc-vimlsp # vimL
        coc-vimtex # latex
        coc-yaml
      ];
    };
}
