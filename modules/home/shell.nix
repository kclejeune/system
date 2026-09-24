_: {
  flake.homeModules.shell =
    {
      config,
      lib,
      pkgs,
      osConfig ? null,
      ...
    }:
    let
      zshCustomPrefix = "oh-my-zsh";
      homeDir = config.home.homeDirectory;
      wtInstall = shell: ''
        if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init ${shell})"; fi
      '';

      slinkyInstall = shell: ''
        if command -v slinky >/dev/null 2>&1; then eval "$(command slinky config hook ${shell})"; fi
      '';
      onNixos = osConfig != null && pkgs.stdenvNoCC.hostPlatform.isLinux;
      ageKey = "${config.xdg.configHome}/sops/age/keys.txt";
    in
    {
      home = {
        preferXdgDirectories = true;
        sessionVariables = {
          # GPG_TTY is per-terminal (set in initContent); TERM and LS_COLORS are left to
          # the terminal and dircolors.
          CLICOLOR = 1;
          LSCOLORS = "ExFxBxDxCxegedabagacad";
          LANG = "en_US.UTF-8";
          DEFAULT_USER = "${config.home.username}";
          MISE_ENV_FILE = ".env";
          AGE_KEY_FILE = ageKey;
          MISE_AGE_KEY_FILE = ageKey;
          SOPS_AGE_KEY_FILE = ageKey;
          FNOX_AGE_KEY_FILE = ageKey;
        }
        // lib.optionalAttrs (!onNixos) {
          # On NixOS nh's hostname default already matches; elsewhere use <user>@<system>.
          NH_HOST = "${config.home.username}@${pkgs.stdenvNoCC.hostPlatform.system}";
        };
        sessionPath = [
          "${homeDir}/.local/bin"
          "${homeDir}/.rustup/bin"
          "${homeDir}/.cargo/bin"
          "${homeDir}/.krew/bin"
        ];
        shellAliases = {
          neofetch = "fastfetch";
          ncdu = "gdu";
          pre-commit = "prek";
          lwt = "lazyworktree";
        }
        // lib.optionalAttrs onNixos {
          # nixpkgs renames Zed's binary to avoid clashing with nodePackages.zed.
          zed = "zeditor";
        };
      };

      xdg =
        let
          mkZshPlugin =
            {
              pkg,
              plugin ? pkg.pname,
            }:
            {
              "${zshCustomPrefix}/plugins/${plugin}" = {
                source = "${pkg.src}";
                recursive = true;
              };
            };
        in
        {
          enable = true;
          dataFile = lib.mergeAttrsList [
            (mkZshPlugin { pkg = pkgs.zsh-autopair; })
            (mkZshPlugin { pkg = pkgs.zsh-completions; })
            (mkZshPlugin { pkg = pkgs.zsh-autosuggestions; })
            (mkZshPlugin {
              pkg = pkgs.zsh-fast-syntax-highlighting;
              plugin = "fast-syntax-highlighting";
            })
            (mkZshPlugin { pkg = pkgs.zsh-history-substring-search; })
          ];
        };
      programs.zsh = {
        enable = true;
        autocd = true;
        dotDir = "${config.xdg.configHome}/zsh";
        sessionVariables = config.home.sessionVariables // {
          ZSH_CUSTOM = "${config.xdg.dataHome}/${zshCustomPrefix}";
        };
        initContent = ''
          unset RPS1
          export GPG_TTY=$TTY
          setopt CHASE_LINKS
          setopt CHASE_DOTS
          ${wtInstall "zsh"}
          # ${slinkyInstall "zsh"}
        '';
        # Non-interactive shells (scripts, CI, agents) skip .zshrc. Turn off NOMATCH (an
        # unmatched glob aborts the whole command) and EQUALS (`echo ===` fails) there;
        # interactive shells keep NOMATCH's typo protection.
        envExtra = ''
          if [[ ! -o interactive ]]; then
            setopt NO_NOMATCH NO_EQUALS
          fi
        '';
        oh-my-zsh = {
          enable = true;
          extraConfig = ''
            export PATH="${homeDir}/.local/bin''${PATH:+:}''${PATH/~\/.local\/bin:/}"
          '';
          plugins = [
            "1password"
            "argocd"
            "brew"
            "git"
            "git-lfs"
            "golang"
            "jfrog"
            "k9s"
            "kitty"
            "kubectl"
            "kubectx"
            "mise"
            "mosh"
            "rclone"
            "ssh"
            "starship"
            "sudo"
            "tailscale"
            "task"
            "terraform"
            "ufw"
            "uv"
            "zoxide"

            # order matters for these ones, probably
            "zsh-autopair"
            "zsh-completions"
            "zsh-autosuggestions"
            "fast-syntax-highlighting"
            "zsh-history-substring-search"
          ];
        };
      };

      programs.bash = {
        enable = true;
        sessionVariables = config.home.sessionVariables // { };
        initExtra = ''
          eval "$(mise activate bash)"
          ${wtInstall "bash"}
          # ${slinkyInstall "bash"}
        '';
      };
    };
}
