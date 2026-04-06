# Thermocline HMI image (rpi-image-gen + Electron kiosk)

This directory is the **source tree** for building the Thermocline Raspberry Pi image with [rpi-image-gen](https://github.com/raspberrypi/rpi-image-gen) and [its documentation](https://raspberrypi.github.io/rpi-image-gen/).

## Flow

1. **Electron** – Top-level `./build.sh` packages `thermocline-electron` for `linux/arm64` into `thermocline-kiosk/electron-dist/`.

2. **Build image** – `rpi-image-gen build -S ./thermocline-kiosk -c config/thermocline.yaml` produces a Debian-based image that enables the `kiosk` systemd unit (Cage + Electron).

## Prerequisites

- **Docker (recommended on Arch)** – Top-level `./build.sh` uses Docker by default when `rpi-image-gen` is not on PATH. It builds an image with Ubuntu + rpi-image-gen + deps (including `python3-ruamel.yaml`) and runs the build in the container. No need to install rpi-image-gen or Python deps on the host.

- **Or rpi-image-gen on the host** – Clone and install deps, then add to PATH:
  ```bash
  git clone https://github.com/raspberrypi/rpi-image-gen.git
  cd rpi-image-gen && sudo ./install_deps.sh
  ```
  You also need Python `ruamel.yaml` (e.g. on Arch: `sudo pacman -S python-ruamel-yaml`).

- **Node/npm** – On the host for packaging Electron (used by `./build.sh`).

## Build from repo root

```bash
./build.sh
```

Or manually: package Electron, then `rpi-image-gen build -S ./thermocline-kiosk -c config/thermocline.yaml` (see prerequisites for Docker vs host).

## Layout

- `config/thermocline.yaml` – Image config (`device.assetid` points at `device/thermocline-rpi4`; includes upstream `trixie-minbase` / `image-rpios` and the kiosk app layer).
- `device/thermocline-rpi4/` – Device assets: `cmdline.txt`, `config.txt` (Pi 4 + official 7" DSI + `uart2`), and executable `post-build.sh` (installs both into `/boot/firmware/`). See [execution / hooks](https://raspberrypi.github.io/rpi-image-gen/execution/) (`DEVICE_ASSET`, post-build phase).
- `layer/thermocline-kiosk.yaml` – App layer: Cage/Electron deps, copies `electron-dist` into the rootfs, installs `kiosk.service`.
- `kiosk.service.tpl` – systemd unit template (`envsubst` with `KIOSK_USER`, `KIOSK_RUNDIR`).
- Optional: `splash.tga` + layer `thermocline-splash` in `config/thermocline.yaml` for a firmware splash ([rpi-splash-screen](https://raspberrypi.github.io/rpi-image-gen/layer/rpi-splash-screen.html)). Disabled by default: `fullscreen_logo*` in cmdline can upset some displays when EDID is missing and was implicated in firmware reset loops during bring-up.

### Boot loop with `DISPLAY_DSI_PORT` (firmware resets, no Linux on serial)

If that message appears **no matter how you edit `config.txt`**, treat it as a **VideoCore / boot-file** problem, not overlay tuning. On the FAT partition, back up then replace **`start4.elf`** and **`fixup4.dat`** (Pi 4) from the [Raspberry Pi firmware `stable` boot folder](https://github.com/raspberrypi/firmware/tree/stable/boot) with the versions from the same commit (do not mix random files). Alternatively, flash **Raspberry Pi OS (64-bit)** once: if that boots on the same Pi + display + SD, hardware is fine and pinning or replacing bootloader files in the Thermocline image build is the next step.
