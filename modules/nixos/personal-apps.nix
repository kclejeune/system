_: {
  # Kept out of `desktop` so a work machine can enroll that without these.
  flake.nixosModules.personal-apps =
    {
      config,
      pkgs,
      ...
    }:
    {
      environment.systemPackages = with pkgs; [
        discord
        notion-app
      ];

      services.syncthing = {
        enable = true;
        user = config.user.name;
        group = "users";
        openDefaultPorts = true;
        dataDir = config.user.home;
      };
    };
}
