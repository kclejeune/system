{ config, pkgs, ... }: {
  # bundles essential nixos modules
  imports = [ ./keybase.nix ];

  services.interception-tools = {
    enable = true;
    plugins = with pkgs.interception-tools-plugins; [ caps2esc ];
    udevmonConfig = ''
      - JOB: intercept -g $DEVNODE | caps2esc -m 1 | uinput -d $DEVNODE
        DEVICE:
          EVENTS:
            EV_KEY: [KEY_CAPSLOCK, KEY_ESC]
    '';
  };

  environment.systemPackages = with pkgs; [ vscode firefox ];

  hm = { pkgs, ... }: { imports = [ ../home-manager/gnome ]; };
}

