{ lib, ... }: {
  imports = [
    ./fzf
    ./lualine-nvim
    ./telescope
    ./theme
    ./treesitter
    ./vim-closetag
  ];
}
