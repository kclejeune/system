{
  config,
  pkgs,
  ...
}: {
  # bundles essential nixos modules
  imports = [./keybase.nix ../common.nix];

  nix.settings = {
    extra-trusted-users = ["${config.user.name}" "@admin" "@root" "@sudo" "@wheel"];
    keep-outputs = true;
    keep-derivations = true;
  };

  services.syncthing = {
    enable = true;
    user = config.user.name;
    group = "users";
    openDefaultPorts = true;
    dataDir = config.user.home;
  };

  environment.systemPackages = with pkgs; [vscode brave gnome-tweaks];

  hm = {...}: {imports = [../home-manager/gnome.nix];};

  # Enable passwordless sudo.
  security.pam.rssh.enable = true;
  security.pam.services.sudo.rssh = true;
  security.sudo.extraConfig = ''
    Defaults noninteractive_auth
  '';

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users = {
    defaultUserShell = pkgs.zsh;
    mutableUsers = false;
    users = {
      "${config.user.name}" = {
        isNormalUser = true;
        extraGroups = ["sudo" "wheel" "docker" "networkmanager"]; # Enable ‘sudo’ for the user.
        hashedPassword = "$6$1kR9R2U/NA0.$thN8N2sTo7odYaoLhipeuu5Ic4CS7hKDt1Q6ClP9y0I3eVMaFmo.dZNpPfdwNitkElkaLwDVsGpDuM2SO2GqP/";
        openssh.authorizedKeys.keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM48VQYrCQErK9QdC/mZ61Yzjh/4xKpgZ2WU5G19FpBG"];
      };
    };
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

  networking.hostName = "nixos"; # Define your hostname.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = pkgs.jetbrains-mono;
  #   keyMap = "us";
  # };

  # Set your time zone.
  # time.timeZone = "EST";
  services.geoclue2.enable = true;
  services.localtimed.enable = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    pinentryPackage = pkgs.pinentry-gnome3;
  };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Enable CUPS to print documents.
  services.printing.enable = true;

  services.pulseaudio.enable = false;

  # Enable touchpad support.
  services.libinput.enable = true;

  # Enable the X11 windowing system.
  services.xserver.enable = true;
  services.xserver.xkb.layout = "us";
  services.desktopManager.gnome.enable = true;
  services.displayManager.gdm.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05";
}
