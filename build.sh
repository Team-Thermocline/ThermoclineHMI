#!/usr/bin/env bash
# Build the Raspberry Pi 4 image in Docker and write output/sdcard.img.

set -e
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
IMAGE_NAME="thermocline-br"
OUTPUT_DIR="$REPO_ROOT/output"

echo "Initializing Buildroot submodule ..."
git submodule update --init "$REPO_ROOT/buildroot"

echo "Building Docker image (if needed) ..."
docker build -t "$IMAGE_NAME" "$REPO_ROOT"

mkdir -p "$OUTPUT_DIR"

echo "Building image in container (this will take a while) ..."
docker run --rm \
  -v "$REPO_ROOT:/work" \
  -w /work \
  "$IMAGE_NAME" \
  bash -c '
    rm -rf buildroot/output &&
    cd buildroot && \
    make BR2_DEFCONFIG=/work/thermocline_defconfig defconfig && \
    make && \
    cp output/images/sdcard.img /work/output/sdcard.img
  '

echo "Done. Image: $OUTPUT_DIR/sdcard.img"
echo "Write to SD: sudo dd if=$OUTPUT_DIR/sdcard.img of=/dev/sdX status=progress bs=4M && sync"
