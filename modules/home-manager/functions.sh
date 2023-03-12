config() {
  # navigate to the config file for a specific app
  cd "$XDG_CONFIG_HOME/$1" || echo "$1 is not a valid config directory."
}
