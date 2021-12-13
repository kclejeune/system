#! /usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Restart Window Manager
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🤖

if ! brew services restart yabai > /dev/null 2>&1; then
    launchctl stop org.nixos.yabai && launchctl start org.nixos.yabai
fi

if ! brew services restart skhd > /dev/null 2>&1; then
    launchctl stop org.nixos.skhd && launchctl start org.nixos.skhd
fi
