{ config, ... }:
(import ../_lib.nix).mkAspect {
  name = "fonts";
  os =
    { pkgs, ... }:
    {
      fonts.packages = with pkgs; [
        jetbrains-mono
        nerd-fonts.jetbrains-mono
      ];
    };
}
