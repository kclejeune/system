_: {
  flake.homeModules.herdr =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      appSettings = (pkgs.formats.json { }).generate "herdr-app-settings.json" {
        zoom = 1.0;
        sounds.enabled = true;
        minimum_contrast = 1.0;
        theme = {
          light = "one-half-light";
          dark = "one-half-dark";
        };
      };
      # GPUI and Ghostty share these source palettes; convert their colors to
      # the JSON format used by herdr-app instead of maintaining another copy.
      appTheme =
        name:
        let
          lines = lib.splitString "\n" (builtins.readFile (./assets/dotfiles/ghostty/themes + "/${name}"));
          color =
            key:
            builtins.head (
              builtins.head (
                builtins.filter (match: match != null) (map (builtins.match "${key}(#[0-9a-fA-F]{6})") lines)
              )
            );
        in
        (pkgs.formats.json { }).generate "herdr-app-${name}.json" {
          background = color "background = ";
          foreground = color "foreground = ";
          cursor = color "cursor-color = ";
          selection = color "selection-background = ";
          ansi = builtins.genList (n: color "palette = ${toString n}=") 16;
        };
      gpuiSettings = (pkgs.formats.toml { }).generate "herdr-gpui-settings.toml" {
        layout = "comfortable-rounded";
        theme = "light:OneHalfLight,dark:OneHalfDark";
        terminal.family = "JetBrains Mono";
        sidebar.family = "JetBrains Mono";
        tabs.family = "JetBrains Mono";
        ui.family = "Open Sans";
      };
    in
    {
      programs.herdr = {
        enable = true;
        package = pkgs.llm-agents.herdr;
        # Preserve settings edited by Herdr while enforcing these preferences.
        mutableSettings = true;
        settings = {
          onboarding = false;
          ui = {
            status_indicators = "symbols";
            toast.delivery = "system";
          };
        };
      };

      home.packages = [
        pkgs.llm-agents.herdr-core
      ]
      ++ lib.optional config.desktop.enable pkgs.llm-agents.herdr-app
      ++ lib.optional (config.desktop.enable && pkgs.stdenv.hostPlatform.isLinux) pkgs.herdr-gpui;

      xdg.configFile = lib.mkIf config.desktop.enable {
        "herdr-app/themes/one-half-light.json".source = appTheme "OneHalfLight";
        "herdr-app/themes/one-half-dark.json".source = appTheme "OneHalfDark";
      };

      # Keep app settings writable while enforcing these preferences on switch.
      home.activation.herdrAppSettings = lib.mkIf config.desktop.enable (
        lib.hm.dag.entryAfter [ "linkGeneration" ] (
          lib.hm.generators.mkImpureConfigMerger {
            inherit pkgs;
            format = "json";
            empty = "{}";
            jqOperation = "$dynamic * $static";
            path = "${config.xdg.configHome}/herdr-app/settings.json";
            staticSettings = appSettings;
            mode = "600";
          }
        )
      );

      # GPUI writes this file too; merge rather than replacing it with a store link.
      home.activation.herdrGpuiSettings = lib.mkIf config.desktop.enable (
        lib.hm.dag.entryAfter [ "linkGeneration" ] (
          lib.hm.generators.mkImpureConfigMerger {
            inherit pkgs;
            format = "toml";
            empty = "{}";
            jqOperation = "$dynamic * $static";
            path = "${config.xdg.configHome}/herdr/config-gpui.local.toml";
            staticSettings = gpuiSettings;
            mode = "600";
          }
        )
      );
    };
}
