{
  self,
  inputs,
  config,
  pkgs,
  ...
}: {
  imports = [
    ./primaryUser.nix
    ./nixpkgs.nix
  ];

  nixpkgs.overlays = builtins.attrValues self.overlays;

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    enableBashCompletion = true;
  };

  user = {
    description = "Kennan LeJeune";
    home = "${
      if pkgs.stdenvNoCC.isDarwin
      then "/Users"
      else "/home"
    }/${config.user.name}";
    shell = pkgs.zsh;
  };

  # bootstrap home manager using system config
  hm = {
    imports = [
      ./home-manager
      ./home-manager/1password.nix
    ];
  };

  # let nix manage home-manager profiles and use global nixpkgs
  home-manager = {
    extraSpecialArgs = {inherit self inputs;};
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
  };

  # environment setup
  environment = {
    systemPackages = with pkgs; [
      # editors
      neovim

      # standard toolset
      coreutils-full
      findutils
      diffutils
      curl
      wget
      git
      jq

      # helpful shell stuff
      bat
      fzf
      ripgrep

      # languages
      python3
      ruby
    ];
    etc = {
      home-manager.source = "${inputs.home-manager}";
      nixpkgs.source = "${inputs.nixpkgs}";
      stable.source = "${inputs.stable}";
    };
    # list of acceptable shells in /etc/shells
    shells = with pkgs; [bash zsh fish];
  };

  fonts = {
    fontDir.enable = true;
    fonts = with pkgs; [jetbrains-mono];
  };
}
