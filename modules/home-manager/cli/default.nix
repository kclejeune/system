{ config, pkgs, lib, ... }:
let
  functions = builtins.readFile ./functions.sh;
  useSkim = false;
  useFzf = !useSkim;
  fuzz = let fd = "${pkgs.fd}/bin/fd";
  in rec {
    defaultCommand = "${fd} -H --type f";
    defaultOptions = [ "--height 50%" ];
    fileWidgetCommand = "${defaultCommand}";
    fileWidgetOptions = [
      "--preview '${pkgs.bat}/bin/bat --color=always --plain --line-range=:200 {}'"
    ];
    changeDirWidgetCommand = "${fd} --type d";
    changeDirWidgetOptions =
      [ "--preview '${pkgs.tree}/bin/tree -C {} | head -200'" ];
    historyWidgetOptions = [ ];
  };
  aliases = { } // (if !pkgs.stdenvNoCC.isDarwin then
    { }
  else {
    # darwin specific aliases
    ibrew = "arch -x86_64 brew";
    abrew = "arch -arm64 brew";
  });
in {
  home.packages = [ pkgs.tree ];
  programs = {
    direnv = {
      enable = true;
      nix-direnv.enable = true;
      stdlib = ''
        # stolen from @i077; store .direnv in cache instead of project dir
        declare -A direnv_layout_dirs
        direnv_layout_dir() {
            echo "''${direnv_layout_dirs[$PWD]:=$(
                echo -n "${config.xdg.cacheHome}"/direnv/layouts/
                echo -n "$PWD" | shasum | cut -d ' ' -f 1
            )}"
        }

        layout_poetry() {
          if [[ ! -f pyproject.toml ]]; then
            log_error 'No pyproject.toml found. Use `poetry new` or `poetry init` to create one first.'
            exit 2
          fi

          # create venv if it doesn't exist
          poetry run true

          export VIRTUAL_ENV=$(poetry env info --path)
          export POETRY_ACTIVE=1
          PATH_add "$VIRTUAL_ENV/bin"
        }
      '';
    };
    skim = {
      enable = useSkim;
      enableBashIntegration = useSkim;
      enableZshIntegration = useSkim;
      enableFishIntegration = useSkim;
    } // fuzz;
    fzf = {
      enable = useFzf;
      enableBashIntegration = useFzf;
      enableZshIntegration = useFzf;
      enableFishIntegration = useFzf;
    } // fuzz;
    bat = {
      enable = true;
      config = {
        theme = "TwoDark";
        color = "always";
      };
    };
    jq.enable = true;
    htop.enable = true;
    gpg.enable = true;
    git = {
      enable = true;
      lfs.enable = true;
      aliases = {
        ignore =
          "!gi() { curl -sL https://www.toptal.com/developers/gitignore/api/$@ ;}; gi";
      };
    };
    go.enable = true;
    exa = {
      enable = true;
      enableAliases = true;
    };
    bash = {
      enable = true;
      shellAliases = aliases;
      initExtra = ''
        ${functions}
      '';
    };
    nix-index.enable = false;
    zsh = let
      mkZshPlugin = { pkg, file ? "${pkg.pname}.plugin.zsh" }: rec {
        name = pkg.pname;
        src = pkg.src;
        inherit file;
      };
    in {
      enable = true;
      autocd = true;
      dotDir = ".config/zsh";
      localVariables = {
        LANG = "en_US.UTF-8";
        GPG_TTY = "/dev/ttys000";
        DEFAULT_USER = "${config.home.username}";
        CLICOLOR = 1;
        LS_COLORS = "ExFxBxDxCxegedabagacad";
        TERM = "xterm-256color";
      };
      shellAliases = aliases;
      initExtraBeforeCompInit = ''
        fpath+=~/.zfunc
      '';
      initExtra = ''
        ${functions}
        ${if pkgs.stdenvNoCC.isDarwin then ''
          [[ -d /opt/homebrew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
        '' else
          ""}
        unset RPS1
      '';
      profileExtra = ''
        ${if pkgs.stdenvNoCC.isLinux then
          "[[ -e /etc/profile ]] && source /etc/profile"
        else
          ""}
      '';
      plugins = with pkgs; [
        (mkZshPlugin { pkg = zsh-autopair; })
        (mkZshPlugin { pkg = zsh-completions; })
        (mkZshPlugin { pkg = zsh-autosuggestions; })
        (mkZshPlugin {
          pkg = zsh-fast-syntax-highlighting;
          file = "fast-syntax-highlighting.plugin.zsh";
        })
        (mkZshPlugin { pkg = zsh-history-substring-search; })
      ];
      oh-my-zsh = {
        enable = true;
        plugins = [ "git" "sudo" ];
      };
    };
    zoxide.enable = true;
    starship = {
      enable = true;
      package = pkgs.stable.starship;
    };
  };
}
