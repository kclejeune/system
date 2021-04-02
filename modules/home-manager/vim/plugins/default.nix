{ ... }: {
  imports = [
    # ./lua-lsp # build failure
    ./bash
    # ./completion-nvim
    ./nvim-autopairs
    ./nvim-compe
    ./css
    ./html
    ./json
    ./latex
    ./lspsga-nvim
    ./nvim-lspconfig
    ./pyright-lsp
    ./rnix-lsp
    ./svelte-lsp
    ./typescript-lsp
    ./vimscript-lsp
    ./vue-lsp
    ./yaml-lsp
    # ./coc
    ./fzf
    ./nerdtree
    ./theme
    ./treesitter
  ];
}
