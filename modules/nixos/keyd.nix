_: {
  flake.nixosModules.keyd = _: {
    services.keyd = {
      enable = true;
      keyboards.default = {
        # The wildcard enrolls keyboards only. Add each touchpad's companion
        # button device explicitly so keyd never grabs its multitouch node.
        ids = [
          "*"
          # Framework 13 (stanley): PIXA3854 companion mouse.
          "m:093a:1343:6b8a0faf"
          # Dell Precision 5570 (wally): Elan companion mouse.
          "m:04f3:311c:5519f33b"
        ];
        settings = {
          main.capslock = "overload(control, esc)";
          # macOS-style Ctrl+click. The control layer consumes Ctrl, so clients
          # receive a plain right-button event rather than Ctrl+right-click.
          control.leftmouse = "rightmouse";
        };
      };
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
