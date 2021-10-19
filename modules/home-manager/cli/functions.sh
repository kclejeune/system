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
    python3 -m venv ./$DIR

    # create .envrc if it isn't already there
    touch .envrc
    cat .envrc | grep "source $DIR/bin/activate" > /dev/null || echo "source $DIR/bin/activate" >> .envrc

    touch .gitignore
    cat .gitignore | grep .envrc > /dev/null || echo .envrc >> .gitignore
    cat .gitignore | grep $DIR > /dev/null || echo "$DIR/" >> .gitignore

    type direnv > /dev/null && direnv allow
}

function weather() {
    curl wttr.in/$1
}

function config() {
    # navigate to the config file for a specific app
    cd "$XDG_CONFIG_HOME/$1" || echo "$1 is not a valid config directory."
}

function service() {
    if [[ -z "$1" ]] then
        echo "no command provided from [stop, start, restart]"
        return 1
    fi
    if [[ -z "$2" ]]; then
        echo "No service name provided"
        return 1
    fi

    service=$(launchctl list | awk "/$2/ {print $NF}")
    if [[ "$1" == "restart" ]]; then
        launchctl stop $service && launchctl start $service
    else
        launchctl $1 $service
    fi
}

_dopy_completion() {
    local IFS=$'
'
    COMPREPLY=( $( env COMP_WORDS="${COMP_WORDS[*]}" \
                   COMP_CWORD=$COMP_CWORD \
                   _DO.PY_COMPLETE=complete_bash $1 ) )
    return 0
}

complete -o default -F _dopy_completion sysdo
