{ config, ... }:
let
  flakeCfg = config;
in
{
  # Each entry becomes `nix run .#<name>` (apply). The other scripts hang off
  # it via derivation passthru: `nix run .#unifi.plan`, `.destroy`, `.init`.
  perSystem =
    { pkgs, ... }:
    {
      terranix.terranixConfigurations.unifi = {
        modules = [ ../terraform/unifi.nix ];

        # Terranix is its own module system and can't see `config.site.*`.
        extraArgs = { inherit (flakeCfg.flake.lib) site; };

        workdir = ".terranix/unifi";

        terraformWrapper = {
          # Not pkgs.terraform: BUSL, marked unfree in nixpkgs, so it would
          # need allowUnfree just to plan.
          package = pkgs.opentofu;
          extraRuntimeInputs = [ pkgs.sops ];

          # Decrypted per-invocation into the wrapper's environment only —
          # never to disk, never to the store.
          prefixText = ''
            secrets="''${NH_FLAKE:-$HOME/.nixpkgs}/secrets/vault.yaml"
            if [ ! -f "$secrets" ]; then
              echo "terranix: sops file not found: $secrets" >&2
              exit 1
            fi

            get() { sops -d --extract "$1" "$secrets"; }

            AWS_ACCESS_KEY_ID="$(get '["rustfs"]["access-key"]')"
            AWS_SECRET_ACCESS_KEY="$(get '["rustfs"]["secret-key"]')"
            TF_VAR_unifi_api_key="$(get '["unifi"]["api-key"]')"
            TF_VAR_wifi_passphrase="$(get '["wifi"]["passphrase"]')"

            export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
            export AWS_REGION=us-east-1
            export TF_VAR_unifi_api_key TF_VAR_wifi_passphrase
          '';
        };
      };
    };
}
