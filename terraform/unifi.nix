# Deliberately NOT under ./modules: everything there is auto-imported by
# import-tree as a flake-parts module, and this is a terranix module.
{ site, ... }:
{
  terraform = {
    # 1.11+ for write-only arguments (passphrase_wo).
    required_version = ">= 1.11";

    required_providers.unifi = {
      source = "ubiquiti-community/unifi";
      version = "~> 0.55";
    };

    # Self-hosted rather than a hosted state service: the unifi provider writes
    # its API key into state in plaintext.
    backend.s3 = {
      bucket = "tfstate";
      key = "unifi/terraform.tfstate";
      region = "us-east-1";

      # The tailnet VIP, not the caddy-lan vhost — s3.lan.kclj.io resolves
      # on-LAN only and needs a manual UniFi Local DNS Record.
      endpoints.s3 = "https://s3.${site.tailnetDomain}";

      # RustFS serves every bucket off one endpoint; virtual-host addressing
      # would need wildcard DNS and a wildcard cert.
      use_path_style = true;

      # Conditional PUT of <key>.tflock, replacing the DynamoDB table RustFS
      # has no analogue for. Verify RustFS honours If-None-Match by racing two
      # plans — if it doesn't, locking is silently a no-op.
      use_lockfile = true;

      # RustFS is not AWS: no STS, no IMDS, no account id, and its ETag is not
      # an MD5 the SDK can verify.
      skip_credentials_validation = true;
      skip_region_validation = true;
      skip_requesting_account_id = true;
      skip_metadata_api_check = true;
      skip_s3_checksum = true;
    };
  };

  variable = {
    unifi_api_key = {
      type = "string";
      sensitive = true;
      description = "UniFi API key (secrets/vault.yaml -> unifi/api-key). Lands in state.";
    };
    wifi_passphrase = {
      type = "string";
      sensitive = true;
      description = "WPA passphrase for Rorschach. Write-only — never persisted to state.";
    };
  };

  provider.unifi = {
    api_url = "https://ui.${site.tailnetDomain}";
    api_key = "\${ var.unifi_api_key }";
    site = "default";
  };

  data.unifi_network.default.name = "Default";

  # Radios tuned 2026-08-13, from measured channel utilisation:
  #
  #   ng  ch1   — best of 1/6/11 by external utilisation (35.0% vs 42.1% on
  #               ch6, 40.9% on ch11). ~35% neighbour load whichever you pick;
  #               there is no better option, only a less bad one.
  #   na  ch36  — pinned OFF DFS. Auto-select kept landing on ch52, where a
  #               radar hit silences the radio for 60s. Congestion was never
  #               the issue — external load on 52 was only ~5%.
  #   6e  ch37  — PSC channel, band measured empty. 160 not 320 MHz: 320
  #               halves PSD and needs a clean 320 MHz block, and only 2 of 21
  #               clients were on 6 GHz at all.
  resource.unifi_device.udr7 = {
    mac = "1c:0b:8b:de:89:a3";
    name = "Dream Router 7";

    # Already adopted; pinned off so a destroy can't unadopt the router that
    # serves this LAN.
    allow_adoption = false;
    forget_on_destroy = false;

    # An attributes list, not blocks. `channel` is a string ("auto" is legal).
    radio_table = [
      {
        name = "wifi0";
        radio = "ng";
        channel = "1";
        ht = 20;
      }
      {
        name = "wifi1";
        radio = "na";
        channel = "36";
        ht = 80;
      }
      {
        name = "wifi2";
        radio = "6e";
        channel = "37";
        ht = 160;
      }
    ];
  };

  # DANGER: the provider PUTs the whole WLAN object on update, so any field
  # omitted here that it doesn't mark Computed is sent as its zero value —
  # which is how you clear a passphrase or drop WPA3. Every field set on the
  # live WLAN is declared below. `plan` must be empty before the first apply.
  resource.unifi_wlan.rorschach = {
    name = "Rorschach";
    security = "wpapsk";
    # No unifi_user_group data source exists, hence the literal id.
    user_group_id = "68872bf2d30a7c5146cc097c";
    network_id = "\${ data.unifi_network.default.id }";

    passphrase_wo = "\${ var.wifi_passphrase }";

    wlan_bands = [
      "2g"
      "5g"
      "6g"
    ];

    # Was 1 Mbps, which let IoT clients transmit at 802.11b rates and burn ~50x
    # the airtime per frame. Inert unless the preference is `manual` — on
    # `auto` the controller ignores the value and reports 1000 back, which
    # reads as permanent drift.
    minrate_setting_preference = "manual";
    minimum_data_rate_2g_kbps = 6000;

    # wpa3_support requires pmf_mode != disabled.
    wpa_mode = "wpa2";
    wpa3_support = true;
    wpa3_transition = true;
    pmf_mode = "optional";

    bss_transition = true;
    no2ghz_oui = true;
  };
}
