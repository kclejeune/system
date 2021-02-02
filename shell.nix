# Flake's devShell for non-flake-enabled nix instances
# as documented at https://nixos.wiki/wiki/Flakes
(import (let lock = builtins.fromJSON (builtins.readFile ./flake.lock);
in fetchTarball {
  url =
    "https://github.com/edolstra/flake-compat/archive/${lock.nodes.flake-compat.locked.rev}.tar.gz";
  sha256 = lock.nodes.flake-compat.locked.narHash;
}) { src = ./.; }).shellNix.default
