{ inputs, nixpkgs, stable, ... }: {
  nixpkgs.overlays = [
    # channels
    (final: prev: {
      # expose other channels via overlays
      stable = import stable { system = prev.system; };
      trunk = import inputs.trunk { system = prev.system; };
      small = import inputs.small { system = prev.system; };

      # install comma from shopify repo
      comma = import inputs.comma rec {
        pkgs = import nixpkgs { system = prev.system; };
      };
    })
    # patches for broken packages
    (final: prev: rec {
      nix-zsh-completions = prev.trunk.nix-zsh-completions;
      tree = prev.trunk.tree;
      nix-direnv = prev.trunk.nix-direnv;
    })
  ];
}
