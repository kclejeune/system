# Terranix configs

Nix-authored Terraform, compiled to `config.tf.json` by the terranix
flake-parts module. Registration lives in `modules/terranix.nix`; the configs
themselves are the `*.nix` files here.

These are deliberately **outside `./modules`** — everything under there is
auto-imported by `import-tree` as a flake-parts module, and a terranix module
is a different thing entirely.

## Usage

```bash
nix run .#unifi.plan      # init + plan
nix run .#unifi           # init + apply
nix develop .#unifi       # shell with plan/apply/destroy/tofu on PATH
```

Credentials are decrypted from `secrets/vault.yaml` per-invocation by the
wrapper's `prefixText` and exist only in that process's environment — never on
disk, never in the store. OpenTofu rather than `pkgs.terraform`, which is BUSL
and marked unfree in nixpkgs.

## unifi.nix

UDR7 radio settings + the Rorschach WLAN. State lives on `vault`'s RustFS
rather than a hosted state service because the unifi provider writes its API
key into state in plaintext.

The backend targets the tailnet VIP (`s3.${site.tailnetDomain}`), so `plan`
works on- and off-LAN with no DNS setup. `site` is passed in via `extraArgs`
from `flake.lib.site` — the same plain data that backs the `config.site.*`
NixOS options, so the tailnet domain is written down once in
`modules/shared/site.nix`. The `s3.lan.kclj.io` caddy vhost is the
LAN-local alternative, but it resolves only on-LAN and needs a manual UniFi
Local DNS Record — caddy can't self-register under UniFi's local domain.
That one vhost serves both the S3 API and the admin console (at
`/rustfs/console/`); a browser hitting its root is redirected there, while
signed API requests pass straight through.

### One-time setup

**1. Secrets.** `secrets/vault.yaml` already carries `unifi/api-key`,
`unifi/base-url` and `unifi/site-id`. Add three more:

```bash
sops secrets/vault.yaml    # rustfs/access-key, rustfs/secret-key, wifi/passphrase
```

Generate the RustFS pair with `openssl rand -hex 32`. Write them straight into
the editor — don't echo them to a terminal.

**2. Deploy vault**, which starts RustFS and creates the `tfstate` bucket:

```bash
nix build .#nixosConfigurations.vault.config.system.build.toplevel
deploy '.#vault'
```

**3. Import.** Both resources describe objects that already exist. Import
before applying, or Terraform will try to create duplicates — and for the WLAN
a create would race the live SSID.

```bash
nix develop .#unifi
tofu import unifi_device.udr7    1c:0b:8b:de:89:a3
tofu import unifi_wlan.rorschach 6886ca11d30a7c5146cc099c
```

Then **`plan` must report no changes.** If it wants to modify anything, the
config has drifted from live state — fix the config, not the router.

## Gotchas

- **The controller silently ignores partial writes.** A `PUT` with one changed
  field returns `rc=ok` and does nothing. The provider sends whole objects, so
  this mostly bites when hand-testing with curl — but it also means any field
  the provider omits gets sent as its zero value. Applying a plan with
  unexplained WLAN diffs can clear the passphrase and drop every wireless
  client at once.
- **`minimum_data_rate_2g_kbps` is inert unless `minrate_setting_preference =
"manual"`.** On `auto` the controller ignores the value and reports `1000`
  back, which reads as permanent drift.
- **`radio_table` is an attributes list, not blocks** — a JSON array, which is
  what the Nix list compiles to. `channel` is a string ("auto" is legal), `ht`
  is a number.
- **`ht` documents 20/40/80/160.** The UDR7's 6 GHz radio supports 320 MHz and
  the REST API accepts it, but 320 is outside the provider's documented range;
  verify it round-trips before relying on it.
- **Never `destroy` here.** `allow_adoption` and `forget_on_destroy` are pinned
  off so destroy can't unadopt the router, but it would still delete the WLAN.
- **Two things need verifying on first run**, because neither is documented as
  supported and both fail quietly:
  - **S3-native locking** (`use_lockfile`) needs RustFS to honour conditional
    writes (`If-None-Match`). Test with two concurrent plans; the second must
    be refused. If it isn't, locking is a silent no-op.
  - **Write-only arguments** (`passphrase_wo`) are a Terraform 1.11 feature.
    Confirm the pinned OpenTofu implements them — if it doesn't, `required_version`
    should catch it at init, but check that the passphrase is genuinely absent
    from state afterward.
- **RustFS is 1.0.0-beta.** Fine for state that's reconstructible by
  re-importing, which this is. Don't put anything irreplaceable in it yet.
