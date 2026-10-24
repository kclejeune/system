_: {
  flake.nixosModules.trusted-network-firewall =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.networking.firewall.trustedNetwork;

      ethernetNetworkType = lib.types.submodule {
        options = {
          connectionId = lib.mkOption {
            type = lib.types.nonEmptyStr;
            description = "NetworkManager connection profile ID.";
          };

          gatewayAddresses = lib.mkOption {
            type = lib.types.listOf lib.types.nonEmptyStr;
            default = [ ];
            description = "Allowed IPv4 gateway addresses for this connection profile.";
          };

          gatewayMacAddresses = lib.mkOption {
            type = lib.types.listOf (lib.types.strMatching "([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}");
            default = [ ];
            description = "Allowed gateway MAC addresses for this connection profile.";
          };
        };
      };

      ruleType = lib.types.submodule {
        options = {
          ssids = lib.mkOption {
            type = lib.types.listOf lib.types.nonEmptyStr;
            default = [ ];
            description = "Wi-Fi SSIDs on which this rule is active.";
          };

          trustedEthernet = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Whether this rule is active on every connected Ethernet
              interface. This trusts the wired network without authenticating
              it; prefer trustedEthernetNetworks where practical.
            '';
          };

          trustedEthernetNetworks = lib.mkOption {
            type = lib.types.listOf ethernetNetworkType;
            default = [ ];
            description = ''
              Ethernet networks trusted when both the active NetworkManager
              connection profile and the configured gateway identifiers match.
            '';
          };

          allowedTCPPorts = lib.mkOption {
            type = lib.types.listOf lib.types.port;
            default = [ ];
            description = "TCP ports opened while this trusted-network rule is active.";
          };

          allowedUDPPorts = lib.mkOption {
            type = lib.types.listOf lib.types.port;
            default = [ ];
            description = "UDP ports opened while this trusted-network rule is active.";
          };
        };
      };

      entries = lib.mapAttrsToList (name: rule: {
        inherit name rule;
        # nftables identifiers have a restricted character set, unlike Nix attr names.
        setName = "trusted-network-${builtins.substring 0 12 (builtins.hashString "sha256" name)}";
      }) cfg.rules;

      hasPinnedEthernetNetworks = lib.any (entry: entry.rule.trustedEthernetNetworks != [ ]) entries;

      hasPinnedGatewayMac = lib.any (
        entry: lib.any (network: network.gatewayMacAddresses != [ ]) entry.rule.trustedEthernetNetworks
      ) entries;

      portsToSet = ports: lib.concatMapStringsSep ", " toString ports;

      reconcile = pkgs.writeShellApplication {
        name = "trusted-network-firewall-reconcile";
        runtimeInputs = [
          pkgs.gawk
          pkgs.iproute2
          pkgs.iputils
          pkgs.networkmanager
          pkgs.nftables
          pkgs.util-linux
        ];
        text = ''
          exec 9>"/run/trusted-network-firewall.lock"
          flock 9

          # The nftables service recreates nixos-fw atomically. If it is not
          # ready yet, its postStart hook or the next NM event will retry.
          nft list table inet nixos-fw >/dev/null 2>&1 || exit 0

          ${lib.concatMapStringsSep "\n" (entry: ''
            nft flush set inet nixos-fw ${lib.escapeShellArg entry.setName} || exit 0
          '') entries}

          while IFS=: read -r iface type state; do
            [[ "$state" == "connected" ]] || continue

            uuid="$(nmcli --get-values GENERAL.CON-UUID device show "$iface" 2>/dev/null || true)"
            [[ -n "$uuid" ]] || continue

            case "$type" in
              wifi)
                ssid="$(nmcli --get-values 802-11-wireless.ssid connection show "$uuid" 2>/dev/null || true)"
                [[ -n "$ssid" ]] || continue

                # An SSID is only a label and can be cloned by any nearby
                # access point. Require the active profile to authenticate the
                # network as well. In particular, reject open, WEP, and OWE
                # profiles; OWE encrypts traffic but does not authenticate the
                # access point.
                key_mgmt="$(nmcli --get-values 802-11-wireless-security.key-mgmt connection show "$uuid" 2>/dev/null || true)"
                case "$key_mgmt" in
                  wpa-psk|sae|wpa-eap|wpa-eap-suite-b-192) ;;
                  *) continue ;;
                esac

                ${lib.concatMapStringsSep "\n" (
                  entry:
                  lib.optionalString (entry.rule.ssids != [ ]) ''
                    case "$ssid" in
                      ${lib.concatMapStringsSep "|" lib.escapeShellArg entry.rule.ssids})
                        nft add element inet nixos-fw ${lib.escapeShellArg entry.setName} "{ \"$iface\" }"
                        ;;
                    esac
                  ''
                ) entries}
                ;;

              ethernet)
                ${lib.optionalString hasPinnedEthernetNetworks ''
                  connection_id="$(nmcli --get-values connection.id connection show "$uuid" 2>/dev/null || true)"
                  gateway="$(nmcli --get-values IP4.GATEWAY device show "$iface" 2>/dev/null || true)"
                ''}

                ${lib.optionalString hasPinnedGatewayMac ''
                  gateway_mac=""
                  if [[ -n "$gateway" ]]; then
                    # Ensure the kernel has attempted neighbor discovery before
                    # consulting its table. Failure is harmless and matching
                    # remains fail-closed when no MAC address can be obtained.
                    ping -c 1 -W 1 -I "$iface" "$gateway" >/dev/null 2>&1 || true
                    gateway_mac="$(
                      ip neigh show "$gateway" dev "$iface" |
                        awk '/lladdr/ { for (i = 1; i <= NF; i++) if ($i == "lladdr") { print tolower($(i + 1)); exit } }'
                    )"
                  fi
                ''}

                ${lib.concatMapStringsSep "\n" (
                  entry:
                  if entry.rule.trustedEthernet then
                    ''
                      nft add element inet nixos-fw ${lib.escapeShellArg entry.setName} "{ \"$iface\" }"
                    ''
                  else
                    lib.optionalString (entry.rule.trustedEthernetNetworks != [ ]) ''
                      ethernet_network_matches=false
                      ${lib.concatMapStringsSep "\n" (network: ''
                        if [[ "$connection_id" == ${lib.escapeShellArg network.connectionId} ]]; then
                          pinned_network_matches=true
                          ${lib.optionalString (network.gatewayAddresses != [ ]) ''
                            case "$gateway" in
                              ${lib.concatMapStringsSep "|" lib.escapeShellArg network.gatewayAddresses}) ;;
                              *) pinned_network_matches=false ;;
                            esac
                          ''}
                          ${lib.optionalString (network.gatewayMacAddresses != [ ]) ''
                            case "$gateway_mac" in
                              ${
                                lib.concatMapStringsSep "|" (
                                  address: lib.escapeShellArg (lib.toLower address)
                                ) network.gatewayMacAddresses
                              }) ;;
                              *) pinned_network_matches=false ;;
                            esac
                          ''}
                          if [[ "$pinned_network_matches" == true ]]; then
                            ethernet_network_matches=true
                          fi
                        fi
                      '') entry.rule.trustedEthernetNetworks}
                      if [[ "$ethernet_network_matches" == true ]]; then
                        nft add element inet nixos-fw ${lib.escapeShellArg entry.setName} "{ \"$iface\" }"
                      fi
                    ''
                ) entries}
                ;;
            esac
          done < <(LC_ALL=C nmcli --terse --escape no --fields DEVICE,TYPE,STATE device status 2>/dev/null || true)
        '';
      };
    in
    {
      options.networking.firewall.trustedNetwork.rules = lib.mkOption {
        type = lib.types.attrsOf ruleType;
        default = { };
        example = lib.literalExpression ''
          {
            administration = {
              ssids = [ "Home Wi-Fi" ];
              trustedEthernetNetworks = [
                {
                  connectionId = "Home Ethernet";
                  gatewayMacAddresses = [ "00:11:22:33:44:55" ];
                }
              ];
              allowedTCPPorts = [ 22 ];
            };
          }
        '';
        description = ''
          Firewall port rules activated on selected authenticated Wi-Fi
          networks or Ethernet connections. Set a rule's trustedEthernet for a
          deliberately broad wired-network fallback.
        '';
      };

      config = lib.mkIf (entries != [ ]) {
        assertions = [
          {
            assertion = config.networking.networkmanager.enable;
            message = "networking.firewall.trustedNetwork requires NetworkManager";
          }
          {
            assertion = config.networking.nftables.enable;
            message = "networking.firewall.trustedNetwork requires nftables";
          }
        ]
        ++ map (entry: {
          assertion =
            entry.rule.ssids != [ ] || entry.rule.trustedEthernet || entry.rule.trustedEthernetNetworks != [ ];
          message = "networking.firewall.trustedNetwork.rules.${entry.name} must trust at least one network";
        }) entries
        ++ lib.concatMap (
          entry:
          map (network: {
            assertion = network.gatewayAddresses != [ ] || network.gatewayMacAddresses != [ ];
            message = "networking.firewall.trustedNetwork.rules.${entry.name}.trustedEthernetNetworks entries must identify at least one gateway address or MAC address";
          }) entry.rule.trustedEthernetNetworks
        ) entries
        ++ map (entry: {
          assertion = entry.rule.allowedTCPPorts != [ ] || entry.rule.allowedUDPPorts != [ ];
          message = "networking.firewall.trustedNetwork.rules.${entry.name} must open at least one port";
        }) entries;

        # The NixOS firewall owns this table. Add interface sets alongside its
        # chains and reference them from the supported extra-input hook.
        networking.nftables.tables."nixos-fw".content = lib.mkAfter (
          lib.concatMapStringsSep "\n" (entry: ''
            set ${entry.setName} {
              type ifname
              comment "Interfaces connected to an allowed trusted network"
            }
          '') entries
        );

        networking.firewall.extraInputRules = lib.mkAfter (
          lib.concatMapStringsSep "\n" (entry: ''
            ${lib.optionalString (entry.rule.allowedTCPPorts != [ ]) ''
              iifname @${entry.setName} tcp dport { ${portsToSet entry.rule.allowedTCPPorts} } accept comment "trusted-network TCP ports"
            ''}
            ${lib.optionalString (entry.rule.allowedUDPPorts != [ ]) ''
              iifname @${entry.setName} udp dport { ${portsToSet entry.rule.allowedUDPPorts} } accept comment "trusted-network UDP ports"
            ''}
          '') entries
        );

        systemd.services.trusted-network-firewall = {
          description = "Reconcile trusted-network firewall rules";
          after = [ "nftables.service" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = lib.getExe reconcile;
          };
        };

        # Repopulate the dynamic interface sets after the firewall is rebuilt.
        systemd.services.nftables.postStart = lib.mkAfter ''
          ${lib.getExe reconcile}
        '';

        networking.networkmanager.dispatcherScripts = [
          {
            source = pkgs.writeText "trusted-network-firewall-dispatcher" /* bash */ ''
              #!${pkgs.runtimeShell}
              ${pkgs.systemd}/bin/systemctl start trusted-network-firewall.service
            '';
          }
        ];
      };
    };
}
