{
  inputs,
  lib,
  ...
}:
{
  # `mkTheme` is a function (not a static attrset) because base16.nix's
  # `mkSchemeAttrs` parses YAML at eval time and needs `pkgs`. Class
  # module bodies have `pkgs` and call `mkTheme pkgs` to get palettes,
  # the loaded scheme attrsets, and GTK name constants. Runtime
  # dark/light toggling is owned by noctalia — see hooks.darkModeChange
  # in modules/home/hyprland.nix.
  flake.lib.mkTheme =
    pkgs:
    let
      base16Lib = inputs.base16.lib { inherit pkgs lib; };
      mkScheme = path: base16Lib.mkSchemeAttrs path;
      # Full base24 schemes from tinted-theming/schemes catalog. To swap
      # to Frappé / Macchiato / Tokyonight / etc.: change the filename.
      catppuccinMocha = mkScheme "${inputs.tinted-schemes}/base24/catppuccin-mocha.yaml";
      catppuccinLatte = mkScheme "${inputs.tinted-schemes}/base24/catppuccin-latte.yaml";

      # Build a Catppuccin-named alias view of a loaded scheme. Most
      # tokens map cleanly to base16/24; `extras` carries Catppuccin
      # gradation colors (overlay0, subtext1) that don't fit standard
      # slots. Per upstream tinted-theming/schemes Catppuccin YAML,
      # `crust` lives at base11 (darkest), `mantle` at base10/base01.
      namedAlias =
        scheme: extras:
        {
          base = scheme.base00;
          mantle = scheme.base01;
          crust = scheme.base11;
          surface0 = scheme.base02;
          surface1 = scheme.base03;
          text = scheme.base05;
          lavender = scheme.base07; # accent
          red = scheme.base08;
          peach = scheme.base09;
          yellow = scheme.base0A;
          green = scheme.base0B;
          blue = scheme.base0D;
          mauve = scheme.base0E;
        }
        // extras;
    in
    {
      # Stylix-ready scheme attrsets — drop into `stylix.base16Scheme`
      # on migration. Stylix accepts attrs directly.
      scheme.dark = catppuccinMocha;
      scheme.light = catppuccinLatte;

      # Catppuccin-named aliases — what current consumers read.
      palettes.dark = namedAlias catppuccinMocha {
        overlay0 = "6c7086"; # mid-gray, no clean base24 mapping
        subtext1 = "bac2de"; # foreground gradation, ~base06 alt
      };
      palettes.light = namedAlias catppuccinLatte {
        overlay0 = "9ca0b0";
        subtext1 = "5c5f77";
      };

      # GTK/cursor/font choices that align to the palette. `accent`
      # and `variant` flow into the `catppuccin-gtk.override` calls
      # in both home + system package lists; `themeName` and
      # `cursorName` are derived so they can't drift from them.
      gtk =
        let
          accent = "blue";
          variant = "mocha";
        in
        {
          inherit accent variant;
          themeName = "catppuccin-${variant}-${accent}-standard";
          cursorName = "catppuccin-${variant}-dark-cursors";
          iconThemeName = "Papirus-Dark";
          fontName = "Open Sans";
          fontSize = 13;
        };
    };
}
