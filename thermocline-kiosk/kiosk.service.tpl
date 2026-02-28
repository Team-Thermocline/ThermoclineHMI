[Unit]
Description=Thermocline Kiosk (Chromium)
After=systemd-time-wait-sync.service thermocline-web.service
Requires=systemd-time-wait-sync.service thermocline-web.service
After=multi-user.target

[Service]
User=$KIOSK_USER
TTYPath=/dev/tty1
Environment="XDG_RUNTIME_DIR=$KIOSK_RUNDIR"
Restart=always
ExecStart=/usr/bin/chromium $KIOSK_URL --kiosk --noerrdialogs --disable-infobars --no-first-run --enable-features=OverlayScrollbar --start-maximized --autoplay-policy=no-user-gesture-required
StandardError=journal

[Install]
WantedBy=default.target
