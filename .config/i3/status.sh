#!/bin/sh
# i3bar status_command: i3status output with the active keyboard layout
# prepended, plus a CAFFEINE block while caffeine.sh keeps the screen on.
# Not named i3status* so `killall i3status` never signals it.
#
# i3bar protocol: a header line, an opening "[", then one JSON array per
# update, every array after the first prefixed with ",".

dir=$(dirname "$0")

i3status -c "$dir/i3status.conf" | {
    read -r line && printf '%s\n' "$line"
    read -r line && printf '%s\n' "$line"
    while read -r line; do
        case $line in
            ,*) sep=, line=${line#,} ;;
            *) sep= ;;
        esac
        layout=$(setxkbmap -query | awk '/^layout:/ { l = $2 } /^variant:/ { v = " (" $2 ")" } END { print l v }')
        caffeine=
        if [ "$("$dir/caffeine.sh" status)" = on ]; then
            caffeine='{"name":"caffeine","full_text":"CAFFEINE","color":"#f0c674"},'
        fi
        printf '%s[%s{"name":"kbd_layout","full_text":"KB: %s"},%s\n' \
            "$sep" "$caffeine" "$layout" "${line#\[}" || exit 1
    done
}
