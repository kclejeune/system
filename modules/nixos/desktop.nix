{
  config,
  pkgs,
  ...
}:
{
  imports = [ ./keybase.nix ];

  services.syncthing = {
    enable = true;
    user = config.user.name;
    group = "users";
    openDefaultPorts = true;
    dataDir = config.user.home;
  };

  environment.systemPackages = with pkgs; [
    vscode
    brave
    gnome-tweaks
  ];

  hm =
    { ... }:
    {
      imports = [
        ../home-manager/gnome.nix
        ../home-manager/1password.nix
      ];
    };

  # Define a user account. Don't forget to set a password with 'passwd'.
  users = {
    mutableUsers = false;
    users = {
      "${config.user.name}" = {
        isNormalUser = true;
        extraGroups = [
          "sudo"
          "wheel"
          "networkmanager"
        ];
        hashedPassword = "$6$1kR9R2U/NA0.$thN8N2sTo7odYaoLhipeuu5Ic4CS7hKDt1Q6ClP9y0I3eVMaFmo.dZNpPfdwNitkElkaLwDVsGpDuM2SO2GqP/";
      };
    };
  };

  networking.hostName = "Phil";
  networking.networkmanager.enable = true;

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  networking.useDHCP = false;
  networking.interfaces.enp0s31f6.useDHCP = true;
  networking.interfaces.wlp4s0.useDHCP = true;

  services.geoclue2.enable = true;
  services.localtimed.enable = true;

  programs.gnupg.agent.pinentryPackage = pkgs.pinentry-gnome3;

  services.printing.enable = true;
  services.pulseaudio.enable = false;
  services.libinput.enable = true;

  services.xserver.enable = true;
  services.xserver.xkb.layout = "us";
  services.desktopManager.gnome.enable = true;
  services.displayManager.gdm.enable = true;

  system.stateVersion = "24.11";
}
