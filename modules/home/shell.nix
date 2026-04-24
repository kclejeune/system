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
    in
    {
      home = {
        preferXdgDirectories = true;
        sessionVariables =
          let
            ageKey = "${config.xdg.configHome}/sops/age/keys.txt";
            # On NixOS, nh os defaults to the system hostname (e.g. "wally"),
            # which matches nixosConfigurations.<host> — so leave NH_HOST unset
            # there. For standalone HM and nix-darwin we still want the
            # hardware-independent "<user>@<system>" scheme.
            onNixos = osConfig != null && pkgs.stdenvNoCC.hostPlatform.isLinux;
          in
          {
            GPG_TTY = "/dev/ttys000";
            CLICOLOR = 1;
            LSCOLORS = "ExFxBxDxCxegedabagacad";
            LANG = "en_US.UTF-8";
            DEFAULT_USER = "${config.home.username}";
            LS_COLORS = "ExFxBxDxCxegedabagacad";
            TERM = "xterm-256color";
            MISE_ENV_FILE = ".env";
            AGE_KEY_FILE = ageKey;
            MISE_AGE_KEY_FILE = ageKey;
            SOPS_AGE_KEY_FILE = ageKey;
            FNOX_AGE_KEY_FILE = ageKey;
          }
          // lib.optionalAttrs (!onNixos) {
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
        };
      };

      programs.atuin = {
        enable = true;
        package = pkgs.atuin;
        daemon.enable = true;
        flags = [ ];
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
          ${wtInstall "zsh"}
          ${slinkyInstall "zsh"}
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
          ${slinkyInstall "bash"}
        '';
      };
    };
}
