_:
(import ../_lib.nix).mkAspect {
  name = "fonts";
  os =
    { pkgs, ... }:
    {
      fonts.packages = with pkgs; [
        jetbrains-mono
        nerd-fonts.jetbrains-mono
        # Fallback icon glyphs for fonts without Nerd Font patches.
        nerd-fonts.symbols-only
        open-sans
      ];
    };
}
