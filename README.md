# dotfiles

## Installing Dotfiles

```
curl -fLo ./yadm https://github.com/TheLocehiliosan/yadm/raw/master/yadm && chmod a+x ./yadm && ./yadm clone https://github.com/kclejeune/dotfiles
```

## Installing Nix Package Manager

Run the following to perform a multifor darwin or standard linux:

```
if [[ $(uname -s) == 'Darwin' ]]; then
    sh <(curl https://nixos.org/nix/install) --daemon --darwin-use-unencrypted-nix-store-volume
else
    sh <(curl https://nixos.org/nix/install) --daemon
fi
```

## Installing Home Manager

`home-manager` bootstraps our user configured packages and program modules. Install it with:

```
nix-channel --add https://nixos.org/channels/nixpkgs-unstable && nix-channel --add https://github.com/rycee/home-manager/archive/master.tar.gz home-manager && nix-channel --update && nix-shell '<home-manager>' -A install
```

To run a generation, use 

```
home-manager switch
```

## Installing `nix-darwin`

```
nix-build https://github.com/LnL7/nix-darwin/archive/master.tar.gz -A installer && ./result/bin/darwin-installer
```
