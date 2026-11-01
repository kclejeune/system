_: {
  flake.homeModules.herdr =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
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
