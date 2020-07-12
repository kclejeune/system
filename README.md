# Dotfiles: System Configuration with Nix

## Installing Nix Package Manager

Run the following to perform a multi-user installation for darwin or standard linux. This step is skipped on NixOS.

```bash
if [[ $(uname -s) == 'Darwin' ]]; then
    sh <(curl https://nixos.org/nix/install) --daemon --darwin-use-unencrypted-nix-store-volume
else
    sh <(curl https://nixos.org/nix/install) --daemon
fi
```

## Cloning Dotfiles

Spawn a shell with `yadm`, clone the repository, and run the bootstrapping script:

```bash
nix-shell -p yadm --run "yadm clone --bootstrap https://github.com/kclejeune/dotfiles"
```

The bootstrap script will clone this repo, build the configuration, and install Homebrew for additional dependencies if we're in a macOS environment.

## Installing Homebrew dependencies

The few leftover homebrew packages and brew casks are stored in `~/Brewfile`. They can be installed using `cd ~ && brew bundle`.
