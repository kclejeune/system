{
  config,
  pkgs,
  ...
}:
{
  # bundles essential nixos modules
  imports = [
    ../common.nix
  ];

  nix.settings = {
    extra-trusted-users = [
      "${config.user.name}"
      "@wheel"
    ];
    keep-outputs = true;
    keep-derivations = true;
  };

  users = {
    defaultUserShell = pkgs.zsh;
  };

  i18n.defaultLocale = "en_US.UTF-8";

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  services.openssh.enable = true;
}
