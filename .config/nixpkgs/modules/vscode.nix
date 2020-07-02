{ config, pkgs, ... }: {
  programs.vscode = {
    enable = false;
    package = pkgs.vscode;
    extensions = with pkgs.vscode-extensions;
      [
        bbenoist.Nix # nix language support
        #   brettm12345.nixfmt-vscode # nix formatter
        #   zhuangtongfa.material-theme # atom one dark pro extension
        #   vscodevim.vim # vim keybindings
        #   esbenp.prettier-vscode # prettier support
        #   ms-python.python # microsoft python LSP
        #   eamodio.gitlens # better git support
      ];
  };
}
