#!/usr/bin/env bash
# Build the Raspberry Pi 4 image in Docker and write output/sdcard.img.

set -e
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
IMAGE_NAME="thermocline-br"
OUTPUT_DIR="$REPO_ROOT/output"

echo "Initializing Buildroot submodule ..."
git submodule update --init "$REPO_ROOT/buildroot"

echo "Building Electron app for Raspberry Pi (arm64)..."
cd "$REPO_ROOT/opt/thermocline-electron"
if [ ! -d "node_modules" ]; then
    echo "Installing npm dependencies..."
    npm install
fi
npm run package:pi
cd "$REPO_ROOT"

echo "Building Docker image (if needed) ..."
docker build -t "$IMAGE_NAME" "$REPO_ROOT"

mkdir -p "$OUTPUT_DIR"

# Create cache directories for Buildroot (persist between builds)
BR_CACHE_DIR="$REPO_ROOT/.buildroot-cache"
mkdir -p "$BR_CACHE_DIR/br-output"
mkdir -p "$BR_CACHE_DIR/dl"

echo "Building image in container (this will take a while) ..."
echo "Using cached build directory: $BR_CACHE_DIR/br-output"
echo "Using cached downloads directory: $BR_CACHE_DIR/dl"
# Pass CLEAN_XSERVER=1 once to force xserver rebuild and re-apply the .pc patch (no full clean)
docker run --rm \
  -v "$REPO_ROOT:/work" \
  -v "$BR_CACHE_DIR/br-output:/work/buildroot/br-output" \
  -v "$BR_CACHE_DIR/dl:/work/buildroot/dl" \
  -w /work \
  ${CLEAN_XSERVER:+ -e CLEAN_XSERVER="$CLEAN_XSERVER"} \
  "$IMAGE_NAME" \
  bash -c '
    cd buildroot && \
    cp /work/thermocline_defconfig configs/ && \
    cp /work/board/raspberrypi4/config_4_64bit.txt board/raspberrypi4-64/config_4_64bit.txt && \
    make O=br-output thermocline_defconfig && \
    make O=br-output rpi-firmware-dirclean && \
    rm -f br-output/images/rootfs.ext2 br-output/images/rootfs.ext4 br-output/images/sdcard.img && \
    if [ -n "${CLEAN_XSERVER:-}" ]; then
      echo "Removing xserver build dir so patch is re-applied (xserver + evdev will rebuild)..."
      make O=br-output xserver_xorg-server-dirclean
    fi && \
    make O=br-output BR2_GLOBAL_PATCH_DIR=/work/board/raspberrypi4/patches && \
    cp br-output/images/sdcard.img /work/output/sdcard.img
  '

# Cleanup
rm -f "$REPO_ROOT/buildroot/configs/thermocline_defconfig"

# Fix ownership on output files (image)
docker run --rm \
  -v "$REPO_ROOT:/work" \
  -v "$BR_CACHE_DIR/br-output:/work/buildroot/br-output" \
  "$IMAGE_NAME" \
  chown -R "$(id -u):$(id -g)" /work/output /work/buildroot/br-output 2>/dev/null || true

echo "Done. Image: $OUTPUT_DIR/sdcard.img"
echo "Verify:      ./scripts/verify-image.sh"
echo "Write to SD: sudo dd if=$OUTPUT_DIR/sdcard.img of=/dev/sdX status=progress bs=4M && sync"
