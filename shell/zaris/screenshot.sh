#!/bin/sh
# Usage: screenshot.sh [region|full]
# region (default): interactive selection via slop, then captured by maim
# full: entire screen

mkdir -p ~/Pictures/Screenshots
filename=~/Pictures/Screenshots/"$(date +%Y-%m-%d_%H-%M-%S).png"

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
