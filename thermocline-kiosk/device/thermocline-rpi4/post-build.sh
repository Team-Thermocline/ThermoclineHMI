#!/bin/sh
# Runs after the rootfs is built (see rpi-image-gen runner: device post-build hook).
set -eu

rootfs="$1"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

# Install our kernel cmdline (same content as cmdline.txt next to this script).
if [ -f "$here/cmdline.txt" ]; then
	install -m 644 "$here/cmdline.txt" "$rootfs/boot/firmware/cmdline.txt"
fi

# Full boot/firmware/config.txt: Pi 4 + official 7" DSI + miniuart-bt (PL011 on GPIO 14/15).
if [ -f "$here/config.txt" ]; then
	install -m 644 "$here/config.txt" "$rootfs/boot/firmware/config.txt"
fi
