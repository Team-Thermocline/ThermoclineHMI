#!/bin/sh
# Run ON the Raspberry Pi (once): sudo bash pi-enable-uart2-ama1.sh
# Optional: appends dtoverlay=uart2 for a *second* PL011 on alternate GPIO (e.g. ttyAMA2), not for GPIO 14/15.
# For controller serial on pins 14/15 only, use miniuart-bt in config.txt (see device/thermocline-rpi4/config.txt).
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
