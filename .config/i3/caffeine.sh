#!/bin/sh
# Caffeine toggle, bound to $mod+i in the i3 config.
#
# Keeps the screen on by switching off the X screensaver and DPMS. xss-lock
# locks on the screensaver event, so with it off the idle lock never fires.
# Manual locking, the power button and suspend still lock as usual.
#
# State lives in the X server, so it lasts until toggled back or the X session
# ends; there is no state file to drift. status.sh reads it for the bar.
#
#   caffeine.sh          toggle
#   caffeine.sh status   print "on" or "off"

# "xset s off" sets the screensaver timeout to 0, which is the on-state marker.
is_on() {
    xset q | grep -q 'timeout:  0 '
}

case ${1:-toggle} in
    status)
        if is_on; then echo on; else echo off; fi
        ;;
    toggle)
        if is_on; then
            # Back to the server defaults (600 s); DPMS keeps its timeouts.
            xset s default +dpms
        else
            xset s off -dpms
        fi
        ;;
    *)
        echo "usage: $0 [toggle|status]" >&2
        exit 2
        ;;
esac
