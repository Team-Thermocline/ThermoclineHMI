[Unit]
Description=Thermocline Kiosk (Electron)
# After crash loops, systemd stops with "Start request repeated too quickly" until: systemctl reset-failed kiosk
StartLimitIntervalSec=120
StartLimitBurst=15
# Cage needs logind + a controlling VT; see https://github.com/cage-kiosk/cage/wiki/Starting-Cage-on-boot-with-systemd
After=multi-user.target systemd-user-sessions.service plymouth-quit-wait.service
After=dbus.socket systemd-logind.service systemd-time-wait-sync.service
Before=graphical.target
Wants=dbus.socket systemd-logind.service
ConditionPathExists=/dev/tty0
# VT7: replace getty so Cage owns the console.
Conflicts=getty@tty7.service
After=getty@tty7.service

[Service]
Type=simple
User=$KIOSK_USER
SupplementaryGroups=video render input dialout tty
PAMName=cage
TTYPath=/dev/tty7
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes
StandardInput=tty-fail
StandardOutput=journal
StandardError=journal
UtmpIdentifier=tty7
UtmpMode=user
Restart=always
RestartSec=5
# Logging/trace → stderr → thermocline-kiosk-launch → /tmp/thermocline-electron.log. Drop THERMO_SERIAL_TRACE to reduce noise.
Environment=ELECTRON_ENABLE_LOGGING=1 THERMO_SERIAL_TRACE=1
# pam_systemd sets XDG_RUNTIME_DIR under /run/user/<uid> — do not override with /home/...
# dbus-run-session: session D-Bus for Electron.
ExecStart=/usr/bin/dbus-run-session -- /usr/bin/cage -- /usr/local/bin/thermocline-kiosk-launch
# Switch to the VT Cage is using (runs with full privileges).
ExecStartPost=+/usr/bin/chvt 7

[Install]
WantedBy=multi-user.target
