_: {
  # atlas — infra / backup node.
  flake.nixosModules.atlas = _: {
    networking.hostName = "atlas";
    sops.defaultSopsFile = ../../secrets/atlas.yaml;
  };
}
