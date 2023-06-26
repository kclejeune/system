{config, ...}: {
  # homebrew.extraConfig = ''
  #   brew "yabai", restart_service: "changed"
  # '';
  services.yabai = {
    enable = true;
    config = {
      mouse_follows_focus = "off";
      focus_follows_mouse = "off";
      window_placement = "second_child";
      window_topmost = "off";
      window_opacity = "off";
      window_opacity_duration = 0.0;
      window_shadow = "on";
      window_border = "off";
      window_border_placement = "inset";
      window_border_width = 4;
      window_border_radius = -1.0;
      active_window_border_topmost = "off";
      active_window_border_color = "0xff775759";
      normal_window_border_color = "0xff505050";
      insert_window_border_color = "0xffd75f5f";
      active_window_opacity = 1.0;
      normal_window_opacity = 0.9;
      split_ratio = 0.5;
      auto_balance = "on";
      mouse_modifier = "fn";
      mouse_action1 = "move";
      mouse_action2 = "resize";
      layout = "bsp";
      top_padding = 5;
      bottom_padding = 5;
      left_padding = 5;
      right_padding = 5;
      window_gap = 5;
    };
    extraConfig = ''
      # Do not manage windows with certain titles eg. Copying files or moving to bin
      yabai -m rule --add title="(Copy|Bin|About This Mac|Info)" manage=off
      # Do not manage some apps which are not resizable
      yabai -m rule --add app="^(Calculator|System Preferences|[sS]tats|[Jj]et[Bb]rains [Tt]ool[Bb]ox)$" manage=off
    '';
  };
}
