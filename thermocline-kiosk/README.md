# Thermocline HMI image (rpi-image-gen + webkiosk)

This directory is the **source tree** for building the Thermocline Raspberry Pi image with [rpi-image-gen](https://github.com/raspberrypi/rpi-image-gen) using the webkiosk pattern.

## Flow

1. **Pack web** – `scripts/pack-web.sh` builds the [team-thermocline.github.io](https://github.com/Team-Thermocline/team-thermocline.github.io) site (Vite) and copies the output into `thermocline-kiosk/web-root`. The kiosk loads `index.html#sender` (the Sender UI).

2. **Build image** – `rpi-image-gen build -S ./thermocline-kiosk -c config/thermocline.yaml` builds a Debian-based image that:
   - Serves the packed web from `/var/www/thermocline` via darkhttpd on port 8080
   - Starts Chromium in kiosk mode on `http://localhost:8080/#sender`

## Prerequisites

- **Docker (recommended on Arch)** – Top-level `./build.sh` uses Docker by default when `rpi-image-gen` is not on PATH. It builds an image with Ubuntu + rpi-image-gen + deps (including `python3-ruamel.yaml`) and runs the build in the container. No need to install rpi-image-gen or Python deps on the host.

- **Or rpi-image-gen on the host** – Clone and install deps, then add to PATH:
  ```bash
  git clone https://github.com/raspberrypi/rpi-image-gen.git
  cd rpi-image-gen && sudo ./install_deps.sh
  ```
  You also need Python `ruamel.yaml` (e.g. on Arch: `sudo pacman -S python-ruamel-yaml`).

- **Node/npm** – For `scripts/pack-web.sh` (team-thermocline.github.io uses Vite). Pack-web runs on the host before the image build.

## Build from repo root

```bash
./scripts/pack-web.sh
rpi-image-gen build -S ./thermocline-kiosk -c config/thermocline.yaml
```

Or use the top-level `./build.sh`, which runs pack-web then rpi-image-gen (in Docker if not on PATH).

## Layout

- `config/thermocline.yaml` – rpi-image-gen config (includes trixie-minbase-ab, thermocline-kiosk layer, kiosk URL).
- `layer/thermocline-kiosk.yaml` – Layer: chromium, darkhttpd, copy web-root into image, systemd units for web server and kiosk.
- `kiosk.service.tpl` – Template for the Chromium kiosk unit (envsubst with `KIOSK_USER`, `KIOSK_RUNDIR`, `KIOSK_URL`).
- `web-root/` – Created by `pack-web.sh`; do not commit (gitignore). Contains the built SPA.

## Optional

- **Splash** – `convert splash.png -resize 1920x1080 -colors 224 splash.tga`