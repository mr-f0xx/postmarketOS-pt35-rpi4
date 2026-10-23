#!/bin/sh
# Read-only diagnostics; no blind I2C probing (which can disturb live drivers).
set -u
printf '\n=== Board ===\n'
tr -d '\000' < /proc/device-tree/model; echo
printf '\n=== Display modes (expect 640x480) ===\n'
for f in /sys/class/drm/card*-HDMI-A-*/modes; do
    [ ! -f "$f" ] || { echo "$f"; cat "$f"; }
done
printf '\n=== Inputs (expect USB keyboard and Goodix touchscreen) ===\n'
cat /proc/bus/input/devices
printf '\n=== Touch driver ===\n'
for f in /sys/bus/i2c/devices/*-005d/name /sys/bus/i2c/devices/*-0014/name; do
    [ ! -f "$f" ] || { echo "$f"; cat "$f"; }
done
printf '\n=== Backlight ===\n'
for backlight in /sys/class/backlight/*; do
    [ -d "$backlight" ] || continue
    echo "$backlight"
    for key in brightness actual_brightness max_brightness; do
        [ ! -f "$backlight/$key" ] || { printf '%s: ' "$key"; cat "$backlight/$key"; }
    done
done
if command -v brightnessctl >/dev/null 2>&1; then brightnessctl --class=backlight --list; fi
printf '\n=== Session / power services ===\n'
if command -v rc-status >/dev/null 2>&1; then rc-status; fi
printf '\n=== Battery ===\n'
found=0
for supply in /sys/class/power_supply/*; do
    [ -f "$supply/type" ] || continue
    [ "$(cat "$supply/type")" = Battery ] || continue
    found=1
    for key in capacity status voltage_now charge_now charge_full; do
        [ ! -f "$supply/$key" ] || { printf '%s: ' "$key"; cat "$supply/$key"; }
    done
done
if [ "$found" -eq 0 ]; then
    echo 'No Linux battery device. Percentage unavailable; RP2040 firmware/protocol integration needed.'
fi
if command -v upower >/dev/null 2>&1; then upower -d; fi
printf '\n=== Manual validation ===\n'
echo 'Use libinput debug-events to test every key and all four touchscreen corners.'
echo 'Check Sway Controls, app grid, lock screen, terminal and on-screen keyboard fit.'
