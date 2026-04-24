_: {
  flake.nixosModules.profile-personal = ../../../profiles/personal;
  flake.darwinModules.profile-personal = ../../../profiles/personal;
  flake.homeModules.profile-personal = ../../../profiles/personal/home-manager;
}
