{...}: {
  imports = [./ollama.nix];
  services.ollama.enable = true;
}
