#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Toggle Dark Mode
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🤖

osascript -e 'tell app "System Events" to tell appearance preferences to set dark mode to not dark mode'

