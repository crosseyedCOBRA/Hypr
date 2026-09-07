#!/bin/bash
# Mirrors ~/.config/qtile/start-qtile.sh: apply the monitor layout before
# ZarisWM starts and enumerates RandR outputs, for the same reason -- ZarisWM's
# setupRandrMonitors() reads whatever RandR reports at connect time.

xrandr \
  --output DisplayPort-0 --mode 1920x1080 --rate 165 --pos 0x0 --rotate normal --primary \
  --output DisplayPort-1 --mode 1920x1080 --rate 144 --rotate right --pos 1920x0 \
  --output DisplayPort-2 --mode 1920x1080 --rate 144 --rotate normal --pos 3000x0 \
  --output HDMI-A-0 --off

exec "$HOME/.local/bin/zaris"
