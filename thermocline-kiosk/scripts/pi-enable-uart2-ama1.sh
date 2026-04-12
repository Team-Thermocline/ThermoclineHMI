#!/bin/sh
# Run ON the Raspberry Pi (once): sudo bash pi-enable-uart2-ama1.sh
# Appends dtoverlay=uart2 if missing (second PL011 on GPIO 0/1; Thermocline images already include it in device/config.txt).
# Use with miniuart-bt so GPIO 14/15 stays primary PL011; Electron prefers /dev/ttyAMA1 then ttyAMA2 for the controller.
# See https://www.raspberrypi.com/documentation/computers/configuration.html#mini-uart-and-cpu-core-frequency
set -eu

if [ "$(id -u)" -ne 0 ]; then
	echo "Run: sudo $0" >&2
	exit 1
fi

cfg=
for c in /boot/firmware/config.txt /boot/config.txt; do
	[ -f "$c" ] && cfg=$c && break
done
[ -n "$cfg" ] || { echo "No /boot/firmware/config.txt or /boot/config.txt found." >&2; exit 1; }

if grep -q '^dtoverlay=uart2' "$cfg"; then
	echo "Already enabled: dtoverlay=uart2 in $cfg"
	exit 0
fi

printf '\n# Thermocline HMI: second PL011 (uart2 overlay; device name varies, e.g. ttyAMA2)\ndtoverlay=uart2\n' >>"$cfg"
echo "Appended dtoverlay=uart2 to $cfg"
echo "Reboot, then check: ls -l /dev/ttyAMA*; groups  # need dialout"
