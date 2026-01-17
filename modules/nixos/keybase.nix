{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    kbfs
    keybase
    keybase-gui
  ];
  services.keybase.enable = true;
  services.kbfs = {
    enable = true;
    # FIXME /keybase needs to be owned by user
    mountPoint = "/keybase";
    extraFlags = [ "-label kbfs" ];
  };

  systemd.user.services = {
    keybase.serviceConfig.Slice = "keybase.slice";

    kbfs = {
      environment = {
        KEYBASE_RUN_MODE = "prod";
      };
      serviceConfig.Slice = "keybase.slice";
    };

    keybase-gui = {
      description = "Keybase GUI";
      requires = [
        "keybase.service"
        "kbfs.service"
      ];
      after = [
        "keybase.service"
        "kbfs.service"
      ];
      serviceConfig = {
        ExecStart = "${pkgs.keybase-gui}/share/keybase/Keybase";
        PrivateTmp = true;
        Slice = "keybase.slice";
      };
    };
  };
}
