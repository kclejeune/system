{ config, ... }:
(import ../_lib.nix).mkAspect {
  name = "identity";
  os =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.identity;
    in
    {
      options.identity = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Whether this host uses the identity module to drive user /
            git / ssh-key config. Off by default so hosts that haven't
            migrated still evaluate cleanly; profiles that want the
            convenience turn it on alongside the identity values.
          '';
        };

        name = lib.mkOption {
          type = lib.types.str;
          description = ''
            Login name of the primary user. Feeds `config.user.name` (which
            aliases `users.users.<name>.*`) so everything that references
            the primary user lines up with a single source of truth.
          '';
        };

        displayName = lib.mkOption {
          type = lib.types.str;
          description = ''
            Full display name (e.g. "Kennan LeJeune"). Used for both the
            user record's description field and git's `user.name` setting.
          '';
        };

        email = lib.mkOption {
          type = lib.types.str;
          description = ''
            Primary email address. Used for git's `user.email` and any
            future tooling that wants a canonical contact address.
          '';
        };

        sshKeys = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            SSH public keys authorized to log in as the primary user.
            Empty list means no key-based login (host falls back to whatever
            the rest of openssh.settings allows).
          '';
        };

        enableRootSshKeys = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            If true, also install `identity.sshKeys` on root's
            authorized_keys. Intended for rescue access on servers where
            locking out of the primary user (mis-configured sudo, disabled
            login shell, etc.) would otherwise require console access.
            Leave off on desktops.
          '';
        };

        sshSigningKey = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            SSH public key used to sign git commits. When set, home-manager
            git config turns on ssh-format signing with this key. The
            signer binary and signByDefault come from the 1password HM
            module — this option just provides the key.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        user.name = cfg.name;
        # GECOS field.
        user.description = cfg.displayName;

        users.users.${cfg.name}.openssh.authorizedKeys.keys =
          lib.mkIf pkgs.stdenv.hostPlatform.isLinux cfg.sshKeys;

        users.users.root.openssh.authorizedKeys.keys = lib.mkIf (
          pkgs.stdenv.hostPlatform.isLinux && cfg.enableRootSshKeys
        ) cfg.sshKeys;

        # Forward identity to the HM-side module so standalone HM hosts
        # that don't go through the nixos/darwin entrypoint still get git
        # identity + signing key populated.
        hm.identity = {
          enable = true;
          displayName = cfg.displayName;
          email = cfg.email;
          sshSigningKey = cfg.sshSigningKey;
        };
      };
    };
  home =
    { config, lib, ... }:
    let
      cfg = config.identity;
    in
    {
      options.identity = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Whether this HM config uses the identity module to populate
            git user/email/signing-key. Off by default so hosts that
            haven't migrated still evaluate cleanly.
          '';
        };
        displayName = lib.mkOption {
          type = lib.types.str;
          description = "Full display name for git commits.";
        };
        email = lib.mkOption {
          type = lib.types.str;
          description = "Primary email address.";
        };
        sshSigningKey = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "SSH public key used to sign git commits.";
        };
      };

      config = lib.mkIf cfg.enable {
        programs.git = {
          settings.user = {
            name = lib.mkDefault cfg.displayName;
            email = lib.mkDefault cfg.email;
          };
          signing.key = lib.mkIf (cfg.sshSigningKey != null) cfg.sshSigningKey;
        };
      };
    };
}
