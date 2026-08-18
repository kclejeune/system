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
          # never to disk, never to the store. The state-bucket creds are
          # vault's (RustFS runs there); the UniFi/Wi-Fi secrets are
          # operator-only and live in terraform.yaml, which no host key can
          # decrypt.
          prefixText = ''
            secrets_dir="''${NH_FLAKE:-$HOME/.nixpkgs}/secrets"
            for f in vault terraform; do
              if [ ! -f "$secrets_dir/$f.yaml" ]; then
                echo "terranix: sops file not found: $secrets_dir/$f.yaml" >&2
                exit 1
              fi
            done

            get() { sops -d --extract "$2" "$secrets_dir/$1.yaml"; }

            AWS_ACCESS_KEY_ID="$(get vault '["rustfs"]["access-key"]')"
            AWS_SECRET_ACCESS_KEY="$(get vault '["rustfs"]["secret-key"]')"
            TF_VAR_unifi_api_key="$(get terraform '["unifi"]["api-key"]')"
            TF_VAR_wifi_passphrase="$(get terraform '["wifi"]["passphrase"]')"

            export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
            export AWS_REGION=us-east-1
            export TF_VAR_unifi_api_key TF_VAR_wifi_passphrase
          '';
        };
      };
    };
}
