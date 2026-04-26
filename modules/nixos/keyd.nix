_: {
  flake.nixosModules.keyd =
    { ... }:
    {
      # Caps Lock -> Esc on tap, Ctrl on hold
      services.keyd = {
        enable = true;
        keyboards.default.settings.main.capslock = "overload(control, esc)";
      };

      # keyd grabs the real keyboard exclusively and re-emits events via a
      # virtual uinput device. That virtual device has no ID_PATH, so libinput
      # classifies it as external and never pairs it with the touchpad for
      # disable-while-typing. Setting a platform-style ID_PATH makes libinput
      # treat it as an internal keyboard and enables DWT.
      services.udev.extraRules = ''
        ACTION=="add", KERNEL=="event*", SUBSYSTEM=="input", \
          ATTRS{name}=="keyd virtual keyboard", \
          ENV{ID_PATH}="platform-keyd", \
          ENV{ID_PATH_TAG}="platform-keyd"
      '';
    };
}
