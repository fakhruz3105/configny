#!/bin/bash

# Set the battery threshold
THRESHOLD=20

# Get the battery status and level
BATTERY_LEVEL=$(cat /sys/class/power_supply/BAT0/capacity)
BATTERY_STATUS=$(cat /sys/class/power_supply/BAT0/status)

# Check if the battery is discharging and below the threshold
if [[ "$BATTERY_STATUS" == "Discharging" && "$BATTERY_LEVEL" -le $THRESHOLD ]]; then
    notify-send -u critical "Low Battery" "Battery level is ${BATTERY_LEVEL}%!"
fi

