{
  inputs,
  lib,
  ...
}:
{
  # A function because base16.nix needs `pkgs` to parse the YAML schemes.
  # Runtime dark/light switching belongs to noctalia.
  flake.lib.mkTheme =
    pkgs:
    let
      base16Lib = inputs.base16.lib { inherit pkgs lib; };
      mkScheme = path: base16Lib.mkSchemeAttrs path;
      catppuccinMocha = mkScheme "${inputs.tinted-schemes}/base24/catppuccin-mocha.yaml";
      catppuccinLatte = mkScheme "${inputs.tinted-schemes}/base24/catppuccin-latte.yaml";

      # `extras` holds Catppuccin gradations with no base16/24 slot.
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
      scheme.dark = catppuccinMocha;
      scheme.light = catppuccinLatte;

      palettes.dark = namedAlias catppuccinMocha {
        overlay0 = "6c7086"; # mid-gray, no clean base24 mapping
        subtext1 = "bac2de"; # foreground gradation, ~base06 alt
      };
      palettes.light = namedAlias catppuccinLatte {
        overlay0 = "9ca0b0";
        subtext1 = "5c5f77";
      };

      # Names derive from accent/variant so they can't drift from the
      # catppuccin-gtk overrides that use them.
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
