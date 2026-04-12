#!/bin/sh
# Run on the Raspberry Pi (Debian / Raspberry Pi OS) as root: sudo ./install-pi-packages.sh
# Installs Cage + DBus + libraries needed for the packaged thermocline-electron binary.
set -eu

if [ "$(id -u)" -ne 0 ]; then
	echo "Run with: sudo $0" >&2
	exit 1
fi

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
	sudo apt-get install -y --no-install-recommends \
	cage \
	dbus \
	psmisc \
	dbus-user-session \
	file \
	fonts-liberation \
	libasound2 \
	libatk-bridge2.0-0 \
	libatk1.0-0 \
	libcups2 \
	libdrm2 \
	libgbm1 \
	libgtk-3-0 \
	libnotify4 \
	libnss3 \
	libvulkan1 \
	libwayland-client0 \
	libwayland-cursor0 \
	libx11-xcb1 \
	libxcb-dri3-0 \
	libxcomposite1 \
	libxdamage1 \
	libxfixes3 \
	libxkbcommon0 \
	libxrandr2 \
	libxss1 \
	libxtst6 \
	wvkbd \
	xdg-utils

echo "Done. Optional (firmware splash): apt install -y rpi-splash-screen-support"
echo "Then copy splash.tga and: sudo configure-splash /path/to/splash.tga"
echo ""
echo "GPIO UART (/dev/serial0, ttyAMA*, etc.): kiosk user needs dialout for SerialPort:"
echo "  sudo usermod -aG dialout pi   # or your username; then log out and back in"
echo "If you use a USB serial adapter that shows up as /dev/ttyACM0 and it never appears,"
echo "  brltty may be grabbing it: sudo systemctl mask brltty-udev.service"
