{ lib, ... }: {
  imports = [
    ./coc
    ./fzf
    ./lualine-nvim
    ./theme
    ./treesitter
    ./vim-closetag
  ];
}
