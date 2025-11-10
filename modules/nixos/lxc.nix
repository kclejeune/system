{
  modulesPath,
  config,
  pkgs,
  ...
}: let
  hostname = "nixos";

  timeZone = "America/New_York";
  defaultLocale = "en_US.UTF-8";
in {
  imports = [
    # Include the default lxc/lxd configuration.
    "${modulesPath}/virtualisation/lxc-container.nix"
  ];

  boot.isContainer = true;
  networking.hostName = hostname;
  time.timeZone = timeZone;

  environment.systemPackages = with pkgs; [
    neovim
  ];

  # networking.firewall.enable = true;
  services.openssh.enable = true;
  services.openssh.openFirewall = true;

  i18n = {
    defaultLocale = defaultLocale;
    extraLocaleSettings = {
      LC_ADDRESS = defaultLocale;
      LC_IDENTIFICATION = defaultLocale;
      LC_MEASUREMENT = defaultLocale;
      LC_MONETARY = defaultLocale;
      LC_NAME = defaultLocale;
      LC_NUMERIC = defaultLocale;
      LC_PAPER = defaultLocale;
      LC_TELEPHONE = defaultLocale;
      LC_TIME = defaultLocale;
    };
  };

  # Enable passwordless sudo.
  security.pam.rssh.enable = true;
  security.pam.services.sudo.rssh = true;
  security.sudo.extraConfig = ''
    Defaults noninteractive_auth
  '';

  users.mutableUsers = false;
  users.users.kclejeune = {
    isNormalUser = true;
    extraGroups = ["sudo" "wheel" "docker"];
    hashedPassword = "$6$1kR9R2U/NA0.$thN8N2sTo7odYaoLhipeuu5Ic4CS7hKDt1Q6ClP9y0I3eVMaFmo.dZNpPfdwNitkElkaLwDVsGpDuM2SO2GqP/";
    openssh.authorizedKeys.keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM48VQYrCQErK9QdC/mZ61Yzjh/4xKpgZ2WU5G19FpBG"];
  };
  nix.settings = {
    extra-trusted-users = ["@admin" "@root" "@sudo" "@wheel"];
    extra-substituters = ["https://kclejeune.cachix.org" "https://install.determinate.systems"];
    extra-trusted-public-keys = ["kclejeune.cachix.org-1:fOCrECygdFZKbMxHClhiTS6oowOkJ/I/dh9q9b1I4ko=" "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="];
    experimental-features = ["nix-command" "flakes"];
  };

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    daemon.settings = {
      features = {
        containerd-snapshotter = true;
      };
    };
  };
  # Supress systemd units that don't work because of LXC.
  # https://blog.xirion.net/posts/nixos-proxmox-lxc/#configurationnix-tweak
  systemd.suppressedSystemUnits = [
    "dev-mqueue.mount"
    "sys-kernel-debug.mount"
    "sys-fs-fuse-connections.mount"
  ];

  system.stateVersion = "25.05";
}
