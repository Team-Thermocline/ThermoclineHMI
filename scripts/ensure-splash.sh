#!/usr/bin/env bash

set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SPLASH="$REPO_ROOT/thermocline-kiosk/splash.tga"

if [ -f "$SPLASH" ]; then
  echo "Using existing splash: $SPLASH"
  exit 0
fi

# Prefer ImageMagick if available (proper size/colors for Pi splash)
if command -v convert >/dev/null 2>&1; then
  echo "Creating default splash with ImageMagick..."
  convert -size 1920x1080 xc:'#0a0a0b' \
    -fill white -gravity center -pointsize 120 -annotate 0 'Thermocline HMI' \
    -colors 224 "$SPLASH"
  echo "Created $SPLASH"
  exit 0
fi

# Fallback: minimal 1x1 black TGA (works with skip_image_checks; will look like a brief black screen)
echo "No ImageMagick found; creating minimal splash.tga (install ImageMagick for a proper splash)"
printf '\x00\x00\x02\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x01\x00\x18\x00\x00\x00\x00' > "$SPLASH"
echo "Created minimal $SPLASH (replace with a proper TGA for a real splash screen)"
exit 0
