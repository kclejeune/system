{ lib, ... }: {
  imports = [
    # ./bash
    # ./css
    # ./go-lsp
    # ./html
    # ./json
    # ./latex
    # ./lspsaga-nvim
    # ./lua-lsp # build failure
    # ./lualine-nvim
    # ./nvim-autopairs
    # ./nvim-compe
    # ./nvim-lspconfig
    # ./pyright-lsp
    # ./rnix-lsp
    # ./svelte-lsp
    # ./typescript-lsp
    # ./vimscript-lsp
    # ./vsnip
    # ./vue-lsp
    # ./yaml-lsp
    # ./skim

    ./coc
    ./theme
    ./treesitter
    ./vim-closetag
    ./fzf
  ];
}
