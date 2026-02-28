# Debug kiosk / no display

After logging in as **root** (no password), run these and capture the output.

**If kiosk is inactive (dead) with no journal entries:** it never started — often due to a failed dependency (e.g. `systemd-time-wait-sync`). Check `systemctl status systemd-time-wait-sync.service`, then try starting the kiosk by hand: `systemctl start kiosk` and run `journalctl -u kiosk -b --no-pager` again.

**If `systemctl start kiosk` hangs forever:** something in the service startup is blocking. In a **second** serial/SSH session (or after Ctrl+C in the first), run:

```bash
# See if cage/chromium are actually running (process started but something blocks)
ps aux | grep -E 'cage|chromium'
```

- If **no** cage/chromium: systemd is stuck before ExecStart (e.g. TTY or user setup). Try removing `TTYPath=/dev/tty1` from the unit, then `systemctl daemon-reload` and `systemctl start kiosk` again (root must be rw: `mount -o remount,rw /`).
- If **yes** cage/chromium: the process started; systemd may still be waiting for something. Run cage **by hand** to see where it blocks and any stderr:

```bash
mount -o remount,rw /
sudo -u pi env XDG_RUNTIME_DIR=/home/pi /usr/bin/cage -s -- /usr/bin/chromium http://localhost:8080/#sender --kiosk --noerrdialogs --disable-infobars --no-first-run 2>&1
```

Leave it running and watch for errors (e.g. DRM, permission, Wayland). Ctrl+C when done.

## 1. Service status

```bash
systemctl status kiosk thermocline-web
```

## 2. Kiosk unit logs (this boot)

```bash
journalctl -u kiosk -b --no-pager
```

## 3. Thermocline-web unit logs

```bash
journalctl -u thermocline-web -b --no-pager
```

## 4. Any cage / chromium / wayland / drm errors in journal

```bash
journalctl -b --no-pager | grep -iE 'cage|chromium|wayland|drm|kms|wlroots|error|fail'
```

## 5. Is the web server up? Can we reach the app?

```bash
curl -sI http://127.0.0.1:8080/
ls -la /var/www/thermocline/
```

## 6. Display / GPU / TTY

```bash
ls -la /dev/dri/
ls -la /dev/tty1
cat /etc/os-release
```

Paste the outputs (or the relevant parts) so we can see why nothing appears on screen.


systemctl status systemd-time-wait-sync.service
systemctl start kiosk
journalctl -u kiosk -b --no-pager