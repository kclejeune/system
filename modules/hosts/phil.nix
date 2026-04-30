{
  self,
  inputs,
  config,
  ...
}:
{
  flake.nixosConfigurations.phil = inputs.nixos-unstable.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit self inputs;
      nixpkgs = inputs.nixos-unstable;
    };
    modules = [
      config.flake.nixosModules.host-baseline
      config.flake.nixosModules.default

      inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t460s
      config.flake.nixosModules.hardware-thinkpad-t460s

      config.flake.nixosModules.desktop
      config.flake.nixosModules.personal-apps
      config.flake.nixosModules.profile-personal

      config.flake.nixosModules.tailscale
      config.flake.nixosModules.netbird

      {
        networking.hostName = "phil";
        # Host-level: pin phil's Hyprland panel/kanshi overlay. The hardware
        # module stays generic so any T460s could reuse it.
        hm.imports = [ config.flake.homeModules.hyprland-host-phil ];
      }
    ];
  };
}
