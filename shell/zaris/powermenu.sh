#!/bin/bash
# Power menu for OpenRC/elogind systems -- uses loginctl (provided by
# elogind) instead of systemctl, since there's no systemd here.
#
# Adapted from ~/.config/qtile/powermenu.sh: only the Logout action differs,
# since qtile's "qtile cmd-obj -o cmd -f shutdown" is qtile-specific.

theme="$HOME/.config/rofi/theme.rasi"

options="Lock\nLogout\nSuspend\nReboot\nShutdown"

chosen=$(echo -e "$options" | rofi -dmenu -i -p "Power" -theme "$theme")

case "$chosen" in
    Lock)
        # Swap for whatever locker you actually have installed --
        # betterlockscreen, physlock, and slock are common OpenRC-friendly
        # choices. Example shown: betterlockscreen.
        betterlockscreen -l blur
        ;;
    Logout)
        pkill zaris
        ;;
    Suspend)
        loginctl suspend
        ;;
    Reboot)
        loginctl reboot
        ;;
    Shutdown)
        loginctl poweroff
        ;;
    *)
        exit 0
        ;;
esac
