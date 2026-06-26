{ config, ... }:
let
  flakeCfg = config;

  # Canonical identity values for Kennan. Kept here so a single const feeds
  # both nixos/darwin hosts (via `os`) and standalone home-manager (via the
  # home body that imports the profile-personal homeModule).
  personalIdentity = rec {
    name = "kclejeune";
    displayName = "Kennan LeJeune";
    email = "kennan@case.edu";
    sshKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM48VQYrCQErK9QdC/mZ61Yzjh/4xKpgZ2WU5G19FpBG"
    ];
    # Same key signs commits as authenticates SSH — 1password manages both.
    sshSigningKey = builtins.head sshKeys;
  };
  # Shared nixos + darwin body: the personal identity (user name, ssh keys,
  # signing key) plus the home-manager profile.
  osBody = _: {
    identity = personalIdentity // {
      enable = true;
    };
    hm.imports = [ flakeCfg.flake.homeModules.profile-personal ];
  };
in
(import ../_lib.nix).mkAspect {
  name = "profile-personal";
  # darwin: identity only — nix-darwin doesn't manage account passwords the way
  # NixOS does, so the hashedPasswordFile wiring below is nixos-only.
  darwin = osBody;
  # nixos: identity + kclejeune's login password, sourced from a sops secret
  # shared across every personal-identity host (secrets/users.yaml, encrypted
  # to each host's SSH host key). neededForUsers makes sops decrypt it before
  # user creation so hashedPasswordFile can read it. Scoping this to
  # profile-personal keeps it off any work machine that consumes this flake
  # without enrolling the personal profile.
  nixos =
    { config, ... }:
    {
      imports = [ osBody ];
      sops.secrets."users/kclejeune/password-hash" = {
        sopsFile = ../../secrets/users.yaml;
        neededForUsers = true;
      };
      users.users.${config.user.name}.hashedPasswordFile =
        config.sops.secrets."users/kclejeune/password-hash".path;
    };
  home = _: {
    # Standalone HM hosts don't go through the nixos/darwin identity
    # module, so populate the identity options directly here. The fields
    # the HM-side identity module cares about are a subset of the os-side
    # ones — no sshKeys / enableRootSshKeys for standalone HM since there's
    # no system-level user to attach them to.
    identity = {
      enable = true;
      inherit (personalIdentity) displayName email sshSigningKey;
    };
  };
}
