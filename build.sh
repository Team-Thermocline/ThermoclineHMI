#!/usr/bin/env bash
# Build Electron for Pi, then build Pi image with rpi-image-gen in Docker. Output: output/sdcard.img

set -e
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
ELECTRON_DIR="$REPO_ROOT/thermocline-electron"
KIOSK_ELECTRON_DIST="$REPO_ROOT/thermocline-kiosk/electron-dist"

echo "Building Electron for Pi (linux arm64)..."
cd "$ELECTRON_DIR"
if [ ! -d "node_modules" ]; then
  npm ci
fi
npm run package:pi

# Forge outputs to out/thermocline-electron-linux-arm64 (see forge.config.js out dir)
PACKAGED="$ELECTRON_DIR/out/thermocline-electron-linux-arm64"
if [ ! -f "$PACKAGED/thermocline-electron" ]; then
  echo "Packaged app not found at $PACKAGED (run npm run package:pi first)"
  exit 1
fi
echo "Copying Electron app from $PACKAGED to thermocline-kiosk/electron-dist..."
rm -rf "$KIOSK_ELECTRON_DIST"
mkdir -p "$KIOSK_ELECTRON_DIST"
cp -a "$PACKAGED"/* "$KIOSK_ELECTRON_DIST/"

echo "Building image..."
if ! grep -q binfmt_misc /proc/mounts 2>/dev/null; then
  echo "binfmt_misc is not loaded. Run once on the host: sudo modprobe binfmt_misc"
  exit 1
fi
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes 2>/dev/null || true
DOCKER_BUILDKIT=1 docker build -q -t thermocline-rpi-image-gen "$REPO_ROOT"
# Remove work/output from previous run (root-owned) unless KEEP_WORK=1
if [ -z "${KEEP_WORK:-}" ]; then
  docker run --rm -v "$REPO_ROOT:/work" --entrypoint "" thermocline-rpi-image-gen rm -rf /work/work /work/output
fi

# Fix ownership of work/output on exit
trap 'docker run --rm -v "$REPO_ROOT:/work" --entrypoint "" thermocline-rpi-image-gen chown -R "$(id -u):$(id -g)" /work/work /work/output 2>/dev/null || true' EXIT
docker run --rm --privileged \
  -v "$REPO_ROOT:/work" -w /work \
  thermocline-rpi-image-gen \
  build -S /work/thermocline-kiosk -c /work/thermocline-kiosk/config/thermocline.yaml

# Find built image (rpi-image-gen puts it in image-* or deploy-* or thermocline-hmi/artefacts)
IMG=""
for cand in "$REPO_ROOT/work/image-thermocline-hmi/thermocline-hmi.img" \
            "$REPO_ROOT/work/thermocline-hmi/artefacts/thermocline-hmi.img"; do
  if [ -f "$cand" ]; then IMG="$cand"; break; fi
done
if [ -z "$IMG" ]; then
  # fallback: any deploy-* or image-* dir with thermocline-hmi.img
  IMG=$(find "$REPO_ROOT/work" -maxdepth 2 -name 'thermocline-hmi.img' -type f 2>/dev/null | head -1)
fi
if [ -n "$IMG" ]; then
  mkdir -p "$REPO_ROOT/output"
  cp -f "$IMG" "$REPO_ROOT/output/sdcard.img"
  echo "Done: output/sdcard.img"
fi
echo "Write to SD: sudo dd if=output/sdcard.img of=/dev/sdX status=progress bs=4M && sync"
