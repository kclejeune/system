_: {
  flake.nixosModules.keyd =
    { ... }:
    {
      # Caps Lock -> Esc on tap, Ctrl on hold
      services.keyd = {
        enable = true;
        keyboards.default.settings.main.capslock = "overload(control, esc)";
      };

      # keyd grabs the real keyboard exclusively (EVIOCGRAB) and re-emits
      # events via a uinput device called `keyd virtual keyboard`. For
      # libinput's disable-while-typing to work, the touchpad needs an
      # *internal* keyboard to pair with — but the keyd device sits on
      # BUS_USB (uinput default), which libinput tags as external.
      #
      # Two pieces:
      #
      #   1. udev: ID_PATH/ID_PATH_TAG=platform-keyd
      #      Gives the virtual keyboard a stable non-USB-looking path.
      #      Cosmetic on its own — keyboard integration tagging is
      #      decided by libinput's quirks framework below, not by udev
      #      properties — but keeps debug output sane and is a no-op
      #      harmless-to-keep.
      #
      #   2. libinput quirks: AttrKeyboardIntegration=internal on the
      #      keyd virtual keyboard. This is the actual knob that makes
      #      DWT pairing kick in. libinput's keyboard tagging lives in
      #      its quirks framework, NOT in the udev properties you'd
      #      expect — setting ID_INPUT_KEYBOARD_INTEGRATION=internal
      #      via udev is silently ignored. The quirks file overrides
      #      the tag by device name.
      #
      # NOTE: we don't need to hide any physical keyboard here. The 5570
      # has an i2c-HID internal keyboard that keyd grabs exclusively, so
      # libinput never sees a competing "internal" keyboard candidate —
      # the keyd virtual keyboard is libinput's only option once the
      # quirk tags it as internal.
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
