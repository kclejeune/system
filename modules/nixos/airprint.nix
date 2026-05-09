_: {
  # AirPrint-compatible CUPS printer sharing. DNS-SD discovery is required
  # but intentionally NOT pulled in here — enroll the `avahi` module
  # alongside this one. The assertion below catches misconfiguration at
  # eval time.
  flake.nixosModules.airprint =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.airprint;
    in
    {
      options.services.airprint = {
        enable = lib.mkEnableOption "AirPrint-compatible CUPS printer sharing";

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Open the CUPS IPP port (TCP 631).";
        };

        ippUsb = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Enable ipp-usb so a USB-attached printer presents itself as
            a network IPP/AirPrint device. Required to share USB-only
            printers; leave off if every printer on the host is already
            networked.
          '';
        };

        commonDrivers = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Include a curated set of CUPS drivers covering the major
            home/SOHO printer manufacturers (Brother, HP, Epson, Canon,
            Samsung/Xerox, plus gutenprint as a broad fallback). Adds
            ~200MB to the system closure; turn off if you only print to
            IPP Everywhere / driverless devices.
          '';
        };

        extraDrivers = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          example = lib.literalExpression "[ pkgs.hplipWithPlugin pkgs.samsung-unified-linux-driver ]";
          description = ''
            Additional CUPS driver packages beyond `commonDrivers` —
            useful for unfree/EULA-gated drivers like hplipWithPlugin
            (HP's proprietary plugin) or vendor-specific Canon/Samsung
            drivers.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.services.avahi.enable;
            message = ''
              services.airprint.enable requires services.avahi.enable = true
              for AirPrint DNS-SD discovery. Enroll the `avahi` nixosModule
              on this host (or set `services.avahi.enable = true` directly).
            '';
          }
        ];

        # AirPrint-friendly CUPS preset:
        #   - listen on every interface so mDNS-discovered clients can
        #     reach the IPP endpoint
        #   - browsing + defaultShared so printers are advertised
        #   - allowFrom "all" matches the LAN-trust assumption AirPrint
        #     requires (CUPS otherwise gates access to localhost)
        services.printing = {
          enable = true;
          listenAddresses = [ "*:631" ];
          allowFrom = [ "all" ];
          browsing = true;
          defaultShared = true;
          openFirewall = cfg.openFirewall;
          drivers =
            (lib.optionals cfg.commonDrivers (
              with pkgs;
              [
                # Broad fallback covering many older Epson/Canon/HP
                # models via gutenprint's PPD library.
                gutenprint
                gutenprintBin
                # Brother — laser default; brgenml1 covers most generic
                # Brother models advertised over USB/network.
                brlaser
                brgenml1lpr
                brgenml1cupswrapper
                # HP (open-source variant — covers most HP devices;
                # add hplipWithPlugin via extraDrivers if your model
                # needs the proprietary plugin).
                hplip
                # Epson inkjets: escpr (older models) + escpr2 (newer
                # AirPrint-era models).
                epson-escpr
                epson-escpr2
                # Canon inkjets via cnijfilter2.
                cnijfilter2
                # Samsung / Xerox color laser (PostScript/SPL-C).
                splix
                # Catch-all for various cheap ZjStream lasers.
                foo2zjs
              ]
            ))
            ++ cfg.extraDrivers;
        };

        services.ipp-usb.enable = cfg.ippUsb;
      };
    };
}
