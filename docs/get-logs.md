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

## 5. Optional: splash and boot

```bash
ls -la /lib/firmware/logo.tga 2>/dev/null || echo "logo.tga not found"
cat /boot/firmware/cmdline.txt 2>/dev/null || cat /boot/cmdline.txt 2>/dev/null
```

---

Paste the output of **1, 2, 3, and 4** (and 5 if you care about splash) so we can see why the screen is black and fix it.
