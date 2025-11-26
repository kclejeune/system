{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}: {
  imports = ["${modulesPath}/profiles/qemu-guest.nix"];
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
    autoResize = true;
  };
  boot.kernelParams = ["console=ttyS0"];
  boot.loader.grub.device = lib.mkDefault "/dev/vda";
  system.build.qcow2 = import "${modulesPath}/../lib/make-disk-image.nix" {
    inherit lib config pkgs;
    diskSize = "auto";
    format = "qcow2";
    partitionTableType = "hybrid";
  };
}
