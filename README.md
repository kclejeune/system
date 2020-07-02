# Dotfiles: System Configuration with Nix

## Installing Nix Package Manager

Run the following to perform a multi-user installation for darwin or standard linux:

```
if [[ $(uname -s) == 'Darwin' ]]; then
    sh <(curl https://nixos.org/nix/install) --daemon --darwin-use-unencrypted-nix-store-volume
else
    sh <(curl https://nixos.org/nix/install) --daemon
fi
```

## Cloning Dotfiles

Create a shell with `yadm`

```
nix-shell -p yadm
```

and clone this repository

```
yadm clone https://github.com/kclejeune/dotfiles
```

When prompted with `y/n`, choose (y) to run `bootstrap` and begin installing the nix configuration. If no prompt appears, do so manually after cloning with

```
yadm bootstrap
```
