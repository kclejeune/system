{ ... }: {
  imports = [
    # ./coc
    # ./lua-lsp # build failure
    ./bash
    ./css
    ./fzf
    ./html
    ./json
    ./latex
    ./lspsaga-nvim
    ./lualine-nvim
    ./nvim-autopairs
    ./nvim-compe
    ./nvim-lspconfig
    ./pyright-lsp
    ./rnix-lsp
    ./svelte-lsp
    ./theme
    ./treesitter
    ./typescript-lsp
    ./vimscript-lsp
    ./vsnip
    ./vue-lsp
    ./yaml-lsp
  ];
}
