# Get logs from the Pi (before changing anything)

Log in as **root** on the Pi (serial or SSH). Run these commands and save the output (copy-paste or redirect to a file).

---

## 1. Kiosk service status

```bash
systemctl status kiosk
```

---

## 2. Kiosk unit logs (this boot)

```bash
journalctl -u kiosk -b --no-pager
```

Cage → `thermocline-kiosk-launch.sh` → Electron: **Electron’s stdout/stderr often never reaches this journal stream.** Use the wrapper and Electron log files:

```bash
tail -200 /tmp/thermocline-kiosk-launch.log
tail -200f /tmp/thermocline-electron.log
```

With **`THERMO_SERIAL_TRACE=1`** in `kiosk.service` (see `kiosk.service.tpl`), that file also includes **`[serial-trace] TX` / `RX`** lines from the main process (truncated to 500 chars) plus **`[serial] status …`** events.

---

## 3. Cage / Electron / errors in the whole boot log

```bash
journalctl -b --no-pager | grep -iE 'cage|thermocline|electron|error|fail|signal|trace'
```

---

## 4. Run Electron by hand (see everything it prints)

This starts the app in the foreground so you see stdout and stderr in the terminal. **Run it, wait a few seconds, then press Ctrl+C.** Copy everything that was printed.

```bash
sudo -u pi env XDG_RUNTIME_DIR=/home/pi \
  dbus-run-session -- /opt/thermocline-electron/thermocline-electron 2>&1
```

---

## 5. Optional: boot cmdline

```bash
cat /boot/firmware/cmdline.txt 2>/dev/null || cat /boot/cmdline.txt 2>/dev/null
```

---

Paste the output of **1, 2, 3, and 4** (and 5 if useful) so we can see why the screen is black and fix it.
