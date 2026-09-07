#!/bin/bash
# Volume OSD helper for the XF86Audio* keybinds in zaris.conf. Adjusts the
# default pipewire sink via wpctl, then tells the OSD popup (OSD.qml) what
# to show via Quickshell's IPC (see its IpcHandler, target "osd").
set -eu

case "$1" in
    up)
        wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+
        ;;
    down)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
        ;;
    mute)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        ;;
esac

status=$(wpctl get-volume @DEFAULT_AUDIO_SINK@) # e.g. "Volume: 0.45" or "Volume: 0.45 [MUTED]"
percent=$(echo "$status" | grep -oP '[\d.]+' | head -1 | awk '{printf "%d", $1 * 100 + 0.5}')
muted=false
echo "$status" | grep -q MUTED && muted=true

qs ipc call osd volume "$percent" "$muted"
