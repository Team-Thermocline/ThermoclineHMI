#!/usr/bin/env bash
# Pack web + build Pi image with rpi-image-gen in Docker. Output: output/sdcard.img

set -e
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "Packing web..."
THERMOCLINE_WEB_ROOT="$REPO_ROOT/thermocline-kiosk/web-root" "$REPO_ROOT/scripts/pack-web.sh"

echo "Building image..."
if ! grep -q binfmt_misc /proc/mounts 2>/dev/null; then
  echo "binfmt_misc is not loaded. Run once on the host: sudo modprobe binfmt_misc"
  exit 1
fi
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes 2>/dev/null || true
docker build -q -t thermocline-rpi-image-gen "$REPO_ROOT"
rm -rf "$REPO_ROOT/work"

# Fix ownership of work/output
trap 'docker run --rm -v "$REPO_ROOT:/work" thermocline-rpi-image-gen chown -R "$(id -u):$(id -g)" /work/work /work/output 2>/dev/null || true' EXIT
docker run --rm --privileged \
  -v "$REPO_ROOT:/work" -w /work \
  thermocline-rpi-image-gen \
  build -S /work/thermocline-kiosk -c /work/thermocline-kiosk/config/thermocline.yaml

if [ -f "$REPO_ROOT/work/thermocline-hmi/artefacts/thermocline-hmi.img" ]; then
  mkdir -p "$REPO_ROOT/output"
  cp -f "$REPO_ROOT/work/thermocline-hmi/artefacts/thermocline-hmi.img" "$REPO_ROOT/output/sdcard.img"
  echo "Done: output/sdcard.img"
fi
echo "Write to SD: sudo dd if=output/sdcard.img of=/dev/sdX status=progress bs=4M && sync"
