#!/usr/bin/env bash
# Pi build inside linux/arm64 Docker. tmpfs on node_modules avoids copying your host (x86) tree.
# Prereq: docker run --rm --privileged tonistiigi/binfmt --install all   (once, if arm64 fails)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ELECTRON_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
IMG="${NODE_ARM64_IMAGE:-node:22-bookworm}"

command -v docker >/dev/null || { echo "docker not in PATH" >&2; exit 1; }

echo "Docker package: $IMG -> $ELECTRON_DIR/out/thermocline-electron-linux-arm64/"

docker run --rm --platform linux/arm64 \
  -e FIXUID="$(id -u)" \
  -e FIXGID="$(id -g)" \
  -v "$ELECTRON_DIR:/work:rw" \
  --tmpfs /work/node_modules:rw,exec,nosuid,nodev,size=2G \
  -w /work \
  "$IMG" \
  bash -lc '
    set -euo pipefail
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq python3 make g++ ca-certificates git >/dev/null
    cd /work
    npm ci
    npm run package:pi
    chown -R "${FIXUID:?}:${FIXGID:?}" /work/out 2>/dev/null || true
  '

echo "Done. rsync: thermocline-electron/out/thermocline-electron-linux-arm64/ -> Pi /opt/thermocline-electron/"
