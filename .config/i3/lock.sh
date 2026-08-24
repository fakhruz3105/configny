#!/bin/bash
# Screen locker wrapper for xsecurelock.
#
# Authenticates via the system-auth PAM service, where pam_fprintd sits ahead of
# pam_unix. Press any key to raise the auth prompt (xsecurelock spawns its auth
# child on first keypress), then either touch the fingerprint reader or type your
# password. Both paths work; fingerprint failure falls through to the password.
#
# Called by xss-lock (on idle, loginctl lock-session, and before suspend).
# exec keeps the sleep lock on fd XSS_SLEEP_LOCK_FD held by xsecurelock itself,
# so xss-lock --transfer-sleep-lock still delays suspend until the screen is up.

export XSECURELOCK_SAVER=saver_blank
export XSECURELOCK_BLANK_TIMEOUT=60
export XSECURELOCK_AUTH_TIMEOUT=60
export XSECURELOCK_SHOW_DATETIME=1
export XSECURELOCK_SHOW_USERNAME=1
export XSECURELOCK_SHOW_HOSTNAME=0
export XSECURELOCK_BACKGROUND_COLOR='#1d1f21'

exec /usr/bin/xsecurelock
