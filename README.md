# Dotfiles: System Configuration with Nix

## Installing Nix Package Manager

Run the following to perform a multi-user installation for darwin or standard linux:

```bash
if [[ $(uname -s) == 'Darwin' ]]; then
    sh <(curl https://nixos.org/nix/install) --daemon --darwin-use-unencrypted-nix-store-volume
else
    sh <(curl https://nixos.org/nix/install) --daemon
fi
```

## Cloning Dotfiles

Create a shell with `yadm`

```bash
nix-shell -p yadm --run "yadm clone --bootstrap https://github.com/kclejeune/dotfiles"
```

and clone this repository

```
```

When prompted with `y/n`, choose (y) to run `bootstrap` and begin installing the nix configuration. If no prompt appears, do so manually after cloning with

```
yadm bootstrap
```
