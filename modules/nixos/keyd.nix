_: {
  flake.nixosModules.keyd = _: {
    services.keyd = {
      enable = true;
      keyboards.default.settings.main.capslock = "overload(control, esc)";
    };

    # keyd's uinput device looks like an external USB keyboard, so libinput
    # won't pair it with the touchpad for disable-while-typing. Only the
    # quirk below fixes that (udev ID_INPUT_KEYBOARD_INTEGRATION is ignored);
    # the udev path is cosmetic.
    services.udev.extraRules = ''
      ACTION=="add", KERNEL=="event*", SUBSYSTEM=="input", \
        ATTRS{name}=="keyd virtual keyboard", \
        ENV{ID_PATH}="platform-keyd", \
        ENV{ID_PATH_TAG}="platform-keyd"
    '';

    environment.etc."libinput/local-overrides.quirks".text = ''
      [keyd virtual keyboard]
      MatchName=keyd virtual keyboard
      AttrKeyboardIntegration=internal
    '';
  };
}
