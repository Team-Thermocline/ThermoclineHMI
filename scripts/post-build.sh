#!/bin/sh
# Run after rootfs is built: RPi board script, then overlay opt/ into target if present.
set -e

# Buildroot sets TARGET_DIR (e.g. buildroot/output/target). Derive paths from it.
BR_DIR="$(cd "$(dirname "$(dirname "$TARGET_DIR")")" && pwd)"
REPO_ROOT="$(cd "$BR_DIR/.." && pwd)"

# Run Raspberry Pi 4 board post-build (HDMI console etc.)
if [ -f "$BR_DIR/board/raspberrypi4-64/post-build.sh" ]; then
    sh "$BR_DIR/board/raspberrypi4-64/post-build.sh"
fi

# Overlay repo opt/ onto rootfs (files here end up in the image root)
if [ -d "$REPO_ROOT/opt" ]; then
    for f in "$REPO_ROOT"/opt/*; do
        [ -e "$f" ] || continue
        cp -a "$f" "$TARGET_DIR/"
    done
fi
