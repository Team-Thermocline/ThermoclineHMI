#!/bin/sh
# Install systemd kiosk unit + Cage launcher on a Raspberry Pi (manual install).
# Prereqs: /opt/thermocline-electron/thermocline-electron exists; run install-pi-packages.sh first.
# Usage: sudo ./install-kiosk-service.sh [kiosk_username]
#   default user: SUDO_USER, or pi
set -eu

if [ "$(id -u)" -ne 0 ]; then
	echo "Run with: sudo $0 [username]" >&2
	exit 1
fi

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
root=$(CDPATH= cd -- "$here/.." && pwd)

if [ "${1-}" ]; then
	KIOSK_USER=$1
else
	KIOSK_USER=${SUDO_USER:-pi}
fi

home=/home/$KIOSK_USER
if [ ! -d "$home" ]; then
	echo "Home directory missing: $home (create user or pass username)" >&2
	exit 1
fi

app=/opt/thermocline-electron/thermocline-electron
if [ ! -x "$app" ]; then
	echo "Install the app first (expected $app)." >&2
	exit 1
fi

install -m 755 "$here/thermocline-kiosk-launch.sh" /usr/local/bin/thermocline-kiosk-launch
install -m 644 "$root/pam.d/cage" /etc/pam.d/cage
export KIOSK_USER
envsubst '$KIOSK_USER' <"$root/kiosk.service.tpl" >/etc/systemd/system/kiosk.service

# Let the kiosk user keep a /run/user/$uid session without a console login (helps some Wayland setups).
if command -v loginctl >/dev/null 2>&1; then
	loginctl enable-linger "$KIOSK_USER" 2>/dev/null || true
fi

systemctl daemon-reload
systemctl enable kiosk.service
systemctl restart kiosk.service || systemctl start kiosk.service

echo "Enabled kiosk.service for user $KIOSK_USER."
echo "  Status: systemctl status kiosk"
echo "  Logs:   journalctl -u kiosk -f"
echo "  Turn off OSK: add Environment=THERMO_DISABLE_OSK=1 under [Service] in /etc/systemd/system/kiosk.service, then systemctl daemon-reload && systemctl restart kiosk"
