# Mirrors flake.nix's nixConfig so the caches also apply outside flake evaluation.
_: {
  flake.lib.caches = {
    substituters = [
      "https://cache.kclj.io"
    ];
    trustedPublicKeys = [
      "cache.kclj.io-1:StGAmbogIZLS5IAQD2IQCbbmIjv3Sq8rl/AVEw4Sy7s="
      "kclejeune:u0sa4anVXC4bKlzEsijdSlLyWVaEkApu6KWyDbbJMkk="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };
}
