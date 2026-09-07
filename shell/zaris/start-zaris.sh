#!/bin/bash
# Applies your monitor layout before ZarisWM starts, since its
# setupRandrMonitors() reads whatever RandR reports at connect time -- if
# you have more than one monitor, or want a specific resolution/rotation,
# that needs to happen here rather than in zaris.conf's exec-once (which
# runs after ZarisWM has already connected and read the layout once).
#
# Left as a no-op by default: single/simple monitor setups don't need any
# of this, X already configures them reasonably on its own. If you do need
# it, run `xrandr --query` to see your own output names, then something
# like:
#
#   xrandr \
#     --output DisplayPort-0 --mode 1920x1080 --rate 165 --pos 0x0 --primary \
#     --output DisplayPort-1 --mode 1920x1080 --rate 144 --rotate right --pos 1920x0

exec "$HOME/.local/bin/zaris"
