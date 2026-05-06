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
in
(import ../_lib.nix).mkAspect {
  name = "profile-personal";
  os = _: {
    identity = personalIdentity // {
      enable = true;
    };
    hm.imports = [ flakeCfg.flake.homeModules.profile-personal ];
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
