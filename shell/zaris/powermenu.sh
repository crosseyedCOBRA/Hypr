#!/bin/bash
# Power menu, using loginctl -- works identically whether it's provided by
# systemd-logind or elogind (its standalone reimplementation for non-systemd
# systems), so no init-system-specific branching needed here.

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
