#!/usr/bin/env bash
# Pack the sender (and minimal site) from team-thermocline.github.io for the Pi kiosk.
# Outputs static assets to THERMOCLINE_WEB_ROOT (default: thermocline-kiosk/web-root).
# Run from repo root. Used by the rpi-image-gen build before building the image.

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GITHUB_IO="$REPO_ROOT/thermocline-electron/team-thermocline.github.io"
OUTPUT_DIR="${THERMOCLINE_WEB_ROOT:-$REPO_ROOT/thermocline-kiosk/web-root}"

cd "$GITHUB_IO"
if [ ! -d "node_modules" ]; then
    echo "Installing team-thermocline.github.io dependencies..."
    npm ci
fi

# Build static site (Vite). For kiosk we only need the SPA; sender is at index.html#sender.
echo "Building team-thermocline.github.io (Vite)..."
npx vite build

mkdir -p "$OUTPUT_DIR"
echo "Copying build output to $OUTPUT_DIR ..."
cp -a dist/. "$OUTPUT_DIR/"

echo "Packed web assets to $OUTPUT_DIR (open index.html#sender for the sender UI)."
