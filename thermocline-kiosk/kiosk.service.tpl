[Unit]
Description=Thermocline Kiosk (Electron)
After=multi-user.target
# Start after time sync if present, but don't block on it
After=systemd-time-wait-sync.service

[Service]
User=$KIOSK_USER
SupplementaryGroups=video render input
Environment="XDG_RUNTIME_DIR=$KIOSK_RUNDIR"
Restart=always
# dbus-run-session gives Electron a session bus (avoids "Failed to connect to the bus" and freezes)
ExecStart=/usr/bin/dbus-run-session -- /usr/bin/cage -s -- /opt/thermocline-electron/thermocline-electron
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
