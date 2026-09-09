#!/bin/sh
# Usage: screenshot.sh [region|full] [folder]
# region (default): interactive selection via slop, then captured by maim
# full: entire screen
# folder (default: ~/Pictures/Screenshots): configurable via Settings'
# Defaults tab (DefaultsConfig.screenshotFolder) - Control Center's own
# screenshot tile always passes it explicitly now, this default only
# matters for a direct/manual invocation of this script.

folder="${2:-$HOME/Pictures/Screenshots}"
mkdir -p "$folder"
filename="$folder/$(date +%Y-%m-%d_%H-%M-%S).png"

case "$1" in
  full)
    maim "$filename"
    ;;
  *)
    maim -s "$filename"
    ;;
esac

# Notify if dunst/notify-send is available -- harmless no-op if not installed
command -v notify-send >/dev/null 2>&1 && notify-send "Screenshot saved" "$filename"

# Copy to clipboard too, if wl-copy/xclip is available
command -v xclip >/dev/null 2>&1 && xclip -selection clipboard -t image/png -i "$filename"
