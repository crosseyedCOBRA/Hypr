#!/bin/bash
# Power menu, using loginctl -- works identically whether it's provided by
# systemd-logind or elogind (its standalone reimplementation for non-systemd
# systems), so no init-system-specific branching needed here.

theme="$HOME/.config/rofi/theme.rasi"

options="Lock\nLogout\nSuspend\nReboot\nShutdown"

chosen=$(echo -e "$options" | rofi -dmenu -i -p "Power" -theme "$theme")

case "$chosen" in
    Lock)
        # Matches zaris.conf's idle-lock locker -- plain i3lock, chosen for
        # being packaged natively on Arch, Debian, and Fedora alike. Swap
        # for a different locker here if you have one you prefer.
        i3lock
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
