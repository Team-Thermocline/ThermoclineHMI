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

## Manual Pi (packages, app at boot, on-screen keyboard)

1. **Packages** (Cage, DBus, Electron libs, **wvkbd** Wayland OSK) — on the Pi:

```bash
scp thermocline-kiosk/scripts/install-pi-packages.sh pi@thermoclinehmi: && ssh pi@thermoclinehmi 'sudo bash install-pi-packages.sh'
```

2. **App** — copy the packaged build (from `./build.sh` → `thermocline-kiosk/electron-dist/`) to `/opt/thermocline-electron/` on the Pi, owned by root, `thermocline-electron` executable (e.g. `sudo rsync -a thermocline-kiosk/electron-dist/ pi@thermoclinehmi:/tmp/electron-dist/` then on the Pi `sudo mkdir -p /opt/thermocline-electron && sudo cp -a /tmp/electron-dist/* /opt/thermocline-electron/`).

3. **systemd kiosk at boot** — keep repo layout under `thermocline-kiosk/` (`kiosk.service.tpl`, `pam.d/cage`, `scripts/install-kiosk-service.sh`, `scripts/thermocline-kiosk-launch.sh`), then on the Pi:

```bash
sudo bash thermocline-kiosk/scripts/install-kiosk-service.sh joe
```

Use your kiosk username. The unit follows [Cage’s systemd recipe](https://github.com/cage-kiosk/cage/wiki/Starting-Cage-on-boot-with-systemd): **`PAMName=cage`**, **`/etc/pam.d/cage`**, **`TTYPath=/dev/tty7`**, **`Conflicts=getty@tty7.service`** (DRM / logind). Compositor uses **VT7** (`chvt 7`); **Ctrl+Alt+F1–F6** for other consoles. Check **`systemctl status kiosk`**.

**Logs:** `journalctl -u kiosk` is often only start/stop. Electron stdout/stderr go to **`/tmp/thermocline-electron.log`**; launcher notes to **`/tmp/thermocline-kiosk-launch.log`**. Syslog tag **`thermocline-kiosk`**: **`journalctl -t thermocline-kiosk -b`**. To skip the OSK: add **`Environment=THERMO_DISABLE_OSK=1`** under **`[Service]`**, then **`sudo systemctl daemon-reload && sudo systemctl restart kiosk`**.

**Numeric entry on the kiosk** — The Sender UI uses an in-app **`KioskNumpad`** (temperature setpoint and graph “Update (ms)” when `isKiosk` is true), so no OS virtual keyboard is required for those fields. The graph omits TDR traces (heater, evaporator, compressor, ambient) in kiosk mode. Optional **wvkbd** is still started by **`thermocline-kiosk-launch.sh`** if installed; see script comments and **`/tmp/thermocline-wvkbd.log`** for diagnostics.

**Controller serial (Pi 4)** — not USB `ttyACM*`. The Thermocline **`config.txt`** uses **`miniuart-bt`** (PL011 on GPIO **14/15** as **`/dev/ttyAMA0`**) and **`dtoverlay=uart2`** (second PL011, usually **`/dev/ttyAMA1`** or **`ttyAMA2`**, on GPIO **0 = TXD2** / **1 = RXD2**, the HAT EEPROM pins). Wire the controller to **UART2**; the app opens **`ttyAMA1`** then **`ttyAMA2`** first. After changes, **`ls -l /dev/ttyAMA*`** and pick the node that matches UART2. Kiosk user needs group **`dialout`**. Manual Pi without the image: `scripts/pi-enable-uart2-ama1.sh` appends **`dtoverlay=uart2`** if missing.

## Layout

- `config/thermocline.yaml` – Image config (`device.assetid` points at `device/thermocline-rpi4`; includes upstream `trixie-minbase` / `image-rpios` and the kiosk app layer).
- `device/thermocline-rpi4/` – Device assets: `cmdline.txt`, `config.txt` (Pi 4 + DSI + `miniuart-bt` + **`uart2`** for controller on GPIO 0/1), and executable `post-build.sh`. See [execution / hooks](https://raspberrypi.github.io/rpi-image-gen/execution/) (`DEVICE_ASSET`, post-build phase).
- `layer/thermocline-kiosk.yaml` – App layer: Cage/Electron deps, copies `electron-dist` into the rootfs, installs `kiosk.service`.
- `kiosk.service.tpl` – systemd unit (`envsubst` with `KIOSK_USER`; VT7 + `PAMName=cage`).
- `pam.d/cage` – PAM stack for that unit (copied to `/etc/pam.d/cage`).
- Optional: `splash.tga` + layer `thermocline-splash` in `config/thermocline.yaml` for a firmware splash ([rpi-splash-screen](https://raspberrypi.github.io/rpi-image-gen/layer/rpi-splash-screen.html)). Disabled by default: `fullscreen_logo*` in cmdline can upset some displays when EDID is missing and was implicated in firmware reset loops during bring-up.

### Boot loop with `DISPLAY_DSI_PORT` (firmware resets, no Linux on serial)

If that message appears **no matter how you edit `config.txt`**, treat it as a **VideoCore / boot-file** problem, not overlay tuning. On the FAT partition, back up then replace **`start4.elf`** and **`fixup4.dat`** (Pi 4) from the [Raspberry Pi firmware `stable` boot folder](https://github.com/raspberrypi/firmware/tree/stable/boot) with the versions from the same commit (do not mix random files). Alternatively, flash **Raspberry Pi OS (64-bit)** once: if that boots on the same Pi + display + SD, hardware is fine and pinning or replacing bootloader files in the Thermocline image build is the next step.
