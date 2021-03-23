#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Restart Window Manager
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🤖

brew services restart yabai && brew services restart skhd

