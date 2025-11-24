{
  pkgs,
  lib,
  ...
}: {
  programs.yazi = {
    enable = true;
    plugins = {
      inherit
        (pkgs.yaziPlugins)
        chmod
        diff
        full-border
        git
        jump-to-char
        lazygit
        mount
        ouch
        piper
        rsync
        smart-enter
        smart-filter
        smart-paste
        starship
        vcs-files
        ;
    };
    extraPackages = with pkgs;
      [
        fd
        lazygit
        ouch
        ripgrep
        rsync
      ]
      ++ lib.optionals (pkgs.stdenvNoCC.isLinux) [util-linux];
    initLua = ./init.lua;
    theme = {
      mgr = {
        preview_hovered = {
          underline = false;
        };
      };
    };
    settings = {
      prepend_previewers = [
        # Archive previewer
        {
          mime = "application/*zip";
          run = "ouch";
        }
        {
          mime = "application/x-tar";
          run = "ouch";
        }
        {
          mime = "application/x-bzip2";
          run = "ouch";
        }
        {
          mime = "application/x-7z-compressed";
          run = "ouch";
        }
        {
          mime = "application/x-rar";
          run = "ouch";
        }
        {
          mime = "application/vnd.rar";
          run = "ouch";
        }
        {
          mime = "application/x-xz";
          run = "ouch";
        }
        {
          mime = "application/xz";
          run = "ouch";
        }
        {
          mime = "application/x-zstd";
          run = "ouch";
        }
        {
          mime = "application/zstd";
          run = "ouch";
        }
        {
          mime = "application/java-archive";
          run = "ouch";
        }
      ];
    };
    keymap = {
      mgr.prepend_keymap = [
        {
          on = ["g" "r"];
          run = "shell -- ya emit cd \"$(git rev-parse --show-toplevel)\"";
        }
        {
          on = [
            "c"
            "m"
          ];
          run = "plugin chmod";
          desc = "Chmod on selected files";
        }
        {
          on = "<C-d>";
          run = "plugin diff";
          desc = "Diff the selected with the hovered file";
        }
        {
          on = "M";
          run = "plugin mount";
        }
        {
          on = "f";
          run = "plugin jump-to-char";
          desc = "Jump to char";
        }
        {
          on = ["C"];
          run = "plugin ouch zst";
          desc = "Compress with ouch";
        }
        {
          on = "l";
          run = "plugin smart-enter";
          desc = "Enter the child directory, or open the file";
        }
        {
          on = "F";
          run = "plugin smart-filter";
          desc = "Smart filter";
        }
        {
          on = "p";
          run = "plugin smart-paste";
          desc = "Paste into the hovered directory or CWD";
        }
        {
          on = ["R"];
          run = "plugin rsync";
          desc = "Copy files using rsync";
        }
        {
          on = [
            "g"
            "i"
          ];
          run = "plugin lazygit";
          desc = "run lazygit";
        }
        # sudo cp/mv
        {
          on = [
            "R"
            "p"
            "p"
          ];
          run = "plugin sudo -- paste";
          desc = "sudo paste";
        }
        # sudo cp/mv --force
        {
          on = [
            "R"
            "P"
          ];
          run = "plugin sudo -- paste --force";
          desc = "sudo paste";
        }
        # sudo mv
        {
          on = [
            "R"
            "r"
          ];
          run = "plugin sudo -- rename";
          desc = "sudo rename";
        }
        # sudo ln -s (absolute-path)
        {
          on = [
            "R"
            "p"
            "l"
          ];
          run = "plugin sudo -- link";
          desc = "sudo link";
        }
        # sudo ln -s (relative-path)
        {
          on = [
            "R"
            "p"
            "r"
          ];
          run = "plugin sudo -- link --relative";
          desc = "sudo link relative path";
        }
        # sudo ln
        {
          on = [
            "R"
            "p"
            "L"
          ];
          run = "plugin sudo -- hardlink";
          desc = "sudo hardlink";
        }
        # sudo touch/mkdir
        {
          on = [
            "R"
            "a"
          ];
          run = "plugin sudo -- create";
          desc = "sudo create";
        }
        # sudo trash
        {
          on = [
            "R"
            "d"
          ];
          run = "plugin sudo -- remove";
          desc = "sudo trash";
        }
        # sudo delete
        {
          on = [
            "R"
            "D"
          ];
          run = "plugin sudo -- remove --permanently";
          desc = "sudo delete";
        }
        # sudo chmod
        {
          on = [
            "R"
            "m"
          ];
          run = "plugin sudo -- chmod";
          desc = "sudo chmod";
        }
      ];
    };
  };
}
