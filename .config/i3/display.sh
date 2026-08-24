#!/bin/bash
# Display refresh, bound to $mod+p in the i3 config.
#
# Re-applies the monitor layout after plugging or unplugging an external
# display: laptop panel on the left as primary, external output to its right.
# Falls back to laptop-only when nothing external is connected.
#
# Note that "xrandr --auto" on its own is not enough. It enables every connected
# output at its preferred mode but leaves them all at +0+0, i.e. mirrored, so
# the positions have to be set explicitly.

INTERNAL=eDP-1

# First connected output that is not the laptop panel (HDMI-1, DP-1, DP-2, ...).
EXTERNAL=$(xrandr --query | awk -v internal="$INTERNAL" \
    '$2 == "connected" && $1 != internal { print $1; exit }')

if [[ -n "$EXTERNAL" ]]; then
    xrandr --output "$INTERNAL" --primary --auto \
           --output "$EXTERNAL" --auto --right-of "$INTERNAL"
    notify-send "Display" "$INTERNAL + $EXTERNAL (right)"
else
    # Switch off any other output so a stale unplugged one is not left enabled.
    for out in $(xrandr --query | awk -v internal="$INTERNAL" \
            '$2 ~ /^(connected|disconnected)$/ && $1 != internal { print $1 }'); do
        xrandr --output "$out" --off
    done
    xrandr --output "$INTERNAL" --primary --auto
    notify-send "Display" "$INTERNAL only"
fi
