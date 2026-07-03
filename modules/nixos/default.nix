{ config, ... }:
let
  flakeCfg = config;
in
{
  # NixOS base: imports the cross-class common-base (shell/user/fonts/env)
  # plus nixos-specific settings (trusted users, default shell, locale,
  # gnupg, openssh).
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
      ];

      nix.settings = {
        extra-trusted-users = [
          "${config.user.name}"
          "@wheel"
        ];
        keep-outputs = true;
        keep-derivations = true;
      };

      users.defaultUserShell = pkgs.zsh;

      i18n.defaultLocale = "en_US.UTF-8";

      programs.gnupg.agent = {
        enable = true;
        enableSSHSupport = true;
      };

      services.openssh.enable = true;
      services.envfs.enable = true;

      # Secure defaults. Every NixOS host gets the firewall on with a
      # conservative ICMP echo rate-limit: enough headroom for interactive
      # debugging (`ping host`), tight enough that an ICMP flood can't
      # saturate a link or tie up softirq. nftables over iptables for the
      networking = {
        # richer rule syntax and better performance; hosts that need the
        # iptables backend can still override.
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

      # Kernel-level network hardening. Reverse-path filtering drops packets
      # whose source address wouldn't route back through the receiving
      # interface (spoofing protection). ICMP redirects — both sending and
      # accepting — are a vector for MITM on untrusted L2 networks and we
      # have no legitimate use for them on any of these hosts. mkDefault so
      # routers or VPN concentrators could override if needed.
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

      # SSH hardening. No password auth anywhere in this repo — all hosts
      # use key-based auth — and no host has a use case for root SSH login.
      # MaxAuthTries / LoginGraceTime keep brute-forcers from holding
      # connections open for free. AllowTcpForwarding is left at the
      # upstream default (true) so `ssh -L` works from desktop hosts;
      # public-facing servers should turn it off explicitly.
      services.openssh.settings = {
        PermitRootLogin = lib.mkDefault "no";
        PasswordAuthentication = lib.mkDefault false;
        MaxAuthTries = lib.mkDefault 3;
        LoginGraceTime = lib.mkDefault 30;
        # Clean up orphaned Unix-domain sockets from prior agent-forwarded
        # sessions. Required for pam_rssh to keep working across reconnects
        # — without it, a stale socket from a previous login blocks the new
        # one from binding.
        StreamLocalBindUnlink = true;
      };

      # Passwordless sudo via SSH agent forwarding. Both flags are required:
      # the first activates the PAM rssh module; the second (a bare bool, not
      # an attrset) wires it into sudo. Authenticating against the SSH agent
      # means remote sessions (`ssh host sudo …`) auth with the forwarded
      # key instead of a password, and local terminals auth with whatever
      # the user's agent already holds.
      security.pam.rssh.enable = true;
      security.pam.services.sudo.rssh = true;

      # By default sudo skips PAM authentication entirely in non-interactive
      # mode (`sudo -n`), assuming auth needs user input — so pam_rssh never
      # runs and `sudo -n` fails with "a password is required". That breaks
      # non-interactive agent auth, e.g. `nh os switch --target-host … -e
      # passwordless`, which runs `sudo --non-interactive`. noninteractive_auth
      # (sudo ≥ 1.9.10) tells sudo to attempt PAM auth even under -n, letting
      # pam_rssh complete its agent round-trip without any prompt.
      security.sudo.extraConfig = "Defaults noninteractive_auth";
    };
}
