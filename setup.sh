#!/usr/bin/env bash
# Team Thermocline

set -e
BUILDROOT_DIR="buildroot"

if [[ ! -f "$BUILDROOT_DIR/Makefile" ]]; then
  echo "Initializing Buildroot submodule ..."
  git submodule update --init "$BUILDROOT_DIR"
fi

cd "$BUILDROOT_DIR"
make raspberrypi4_64_defconfig
make

echo "Done. Image: $(pwd)/output/images/sdcard.img"
echo "Write to SD: sudo dd if=output/images/sdcard.img of=/dev/sdX status=progress bs=4M"
