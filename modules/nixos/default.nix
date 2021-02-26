{ config, pkgs, ... }: {
  # bundles essential nixos modules
  imports = [ ./keybase.nix ];

  services.interception-tools = {
    enable = true;
    plugins = with pkgs.interception-tools-plugins; [ caps2esc ];
  };

  environment.systemPackages = with pkgs; [
    vscode
    firefox
  ];

  hm = { pkgs, ... }: { imports = [ ../gnome ]; };
}

