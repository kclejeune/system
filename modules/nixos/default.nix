{ config, ... }:
let
  flakeCfg = config;
in
{
  flake.nixosModules.default =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [
        flakeCfg.flake.nixosModules.common-base
        flakeCfg.flake.nixosModules.primary-user
        flakeCfg.flake.nixosModules.identity
        flakeCfg.flake.nixosModules.nixpkgs-wiring
        flakeCfg.flake.nixosModules.site
        flakeCfg.flake.nixosModules.resolv-reload
        flakeCfg.flake.nixosModules.nix-caches
      ];

      nix.settings = {
        extra-trusted-users = [
          "${config.user.name}"
          "@wheel"
        ];
        # Build-time closures only pay off for dev shells; on servers that build
        # their own generations (comin) they pin every toolchain and fill /nix.
        keep-outputs = lib.mkDefault false;
        keep-derivations = lib.mkDefault false;
        # Let Nix collect garbage mid-build instead of failing with a full disk,
        # which also wedges the store DB and nh-clean with it. Small disks lower these.
        min-free = lib.mkDefault (20 * 1024 * 1024 * 1024);
        max-free = lib.mkDefault (50 * 1024 * 1024 * 1024);
      };

      users.defaultUserShell = pkgs.zsh;

      i18n.defaultLocale = "en_US.UTF-8";

      # No enableSSHSupport: gpg-agent would fight 1Password / the forwarded
      # agent for SSH_AUTH_SOCK.
      programs.gnupg.agent.enable = true;

      # determinate-nixd's GC can't trim system generations (they're gcroots).
      programs.nh.clean = {
        enable = true;
        dates = "daily";
        extraArgs = "--keep 3";
      };

      services.openssh.enable = true;
      # So SSH sessions from kitty/ghostty keep their native TERM. Not
      # enableAllTerminfo: it builds every listed terminal, and one breaking
      # (contour on GCC 16) takes down every host.
      environment.systemPackages = [
        pkgs.kitty.terminfo
        pkgs.ghostty.terminfo
      ];

      # Kill the user cgroup under sustained memory pressure instead of
      # thrashing. Two parallel rustc builds wedged atlas for 1.5 days once the
      # kernel OOM killer had taken one and the page cache was gone.
      systemd.oomd = {
        enable = lib.mkDefault true;
        enableUserSlices = lib.mkDefault true;
      };

      # An OOM kill ends only the killed process. With the default "stop" it
      # also stops the unit or scope around it: a multiplexer with every shell
      # in it, or an SSH session.
      systemd.settings.Manager.DefaultOOMPolicy = lib.mkDefault "continue";
      systemd.user.settings.Manager.DefaultOOMPolicy = lib.mkDefault "continue";

      # Keep remote access alive while a host thrashes. Not OOMScoreAdjust on
      # sshd: sessions inherit it, so builds over SSH would become unkillable.
      systemd.services.sshd.serviceConfig.MemoryMin = lib.mkDefault "64M";
      systemd.services.tailscaled.serviceConfig = lib.mkIf config.services.tailscale.enable {
        MemoryMin = lib.mkDefault "128M";
        OOMScoreAdjust = lib.mkDefault (-900);
      };

      networking = {
        nftables.enable = lib.mkDefault true;
        firewall = {
          enable = lib.mkDefault true;
          pingLimit = lib.mkDefault (
            if config.networking.nftables.enable then
              "2/second burst 5 packets"
            else
              "--limit 2/second --limit-burst 5"
          );
        };
      };

      # Anti-spoofing; ICMP redirects are a MITM vector on untrusted L2.
      boot.kernel.sysctl = {
        "net.ipv4.conf.all.rp_filter" = lib.mkDefault 1;
        "net.ipv4.conf.default.rp_filter" = lib.mkDefault 1;
        "net.ipv4.conf.all.send_redirects" = lib.mkDefault 0;
        "net.ipv4.conf.default.send_redirects" = lib.mkDefault 0;
        "net.ipv4.conf.all.accept_redirects" = lib.mkDefault 0;
        "net.ipv4.conf.default.accept_redirects" = lib.mkDefault 0;
        "net.ipv6.conf.all.accept_redirects" = lib.mkDefault 0;
        "net.ipv6.conf.default.accept_redirects" = lib.mkDefault 0;
      };

      # AllowTcpForwarding stays at upstream's default so `ssh -L` works;
      # public servers turn it off themselves.
      services.openssh.settings = {
        PermitRootLogin = lib.mkDefault "no";
        PasswordAuthentication = lib.mkDefault false;
        # Pinned so a future SSH PAM auth module can't silently enable it.
        KbdInteractiveAuthentication = lib.mkDefault false;
        MaxAuthTries = lib.mkDefault 3;
        LoginGraceTime = lib.mkDefault 30;
        # A stale forwarded-agent socket would otherwise break pam_rssh on reconnect.
        StreamLocalBindUnlink = true;
      };

      # sudo authenticates against the (forwarded) SSH agent, not a password.
      security.pam.rssh.enable = true;
      security.pam.services.sudo.rssh = true;

      # `sudo -n` skips PAM by default, so pam_rssh would never run for
      # `nh --target-host -e passwordless`.
      security.sudo.extraConfig = "Defaults noninteractive_auth";
    };
}
