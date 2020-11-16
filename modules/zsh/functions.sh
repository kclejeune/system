function mkvenv() {
    if [[ -z "$1" ]]; then
        DIR="venv"
    else
        DIR=$1
    fi

    if [[ -d $DIR ]]; then
        echo "Remove existing virtual environment? (y/n)"
        read removeExisting
        if [[ $removeExisting == "y" || $removeExisting == "Y" ]]; then
            rm -rf $DIR
        else
            return 0
        fi
    fi

    # make a new virtual environment with the desired directory name
    if type virtualenv > /dev/null; then
        virtualenv ./$DIR
    else
        python3 -m venv ./$DIR
    fi

    # create .envrc if it isn't already there
    touch .envrc
    cat .envrc | grep "source $DIR/bin/activate" > /dev/null || echo "source $DIR/bin/activate" >> .envrc
    cat .envrc | grep "unset PS1" > /dev/null || echo "unset PS1" >> .envrc

    touch .gitignore
    cat .gitignore | grep .env
    cat .gitignore | grep .envrc > /dev/null ||echo .envrc >>.gitignore
    cat .gitignore | grep $DIR > /dev/null ||echo "$DIR/" >>.gitignore

    type direnv > /dev/null & direnv allow
}

function weather() {
    curl wttr.in/$1
}

function config() {
    # navigate to the config file for a specific app
    cd "$XDG_CONFIG_HOME/$1"
}

function restartService() {
    if [[ -z "$1" ]]; then
        echo "No service name provided"
        return 0
    fi

    service=$(launchctl list | grep $1 | awk '{print $NF}')
    launchctl stop $service && launchctl start $service
}

function rebuildFlake() {
    command -v darwin-rebuild > /dev/null && darwin-rebuild --flake "$HOME/.nixpkgs/#Randall" $@
    command -v nixos-rebuild > /dev/null && sudo nixos-rebuild --flake "/etc/nixos/#Phil" $@
}

