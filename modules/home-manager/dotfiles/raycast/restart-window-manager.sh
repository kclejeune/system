#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Restart Window Manager
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🤖

brew services restart yabai && brew services restart skhd
# launchctl stop org.nixos.yabai && launchctl start org.nixos.yabai
# launchctl stop org.nixos.skhd && launchctl start org.nixos.skhd
