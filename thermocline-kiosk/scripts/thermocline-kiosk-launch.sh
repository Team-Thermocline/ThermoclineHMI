#!/bin/sh
# Run inside Cage (Wayland): optional on-screen keyboard over fullscreen kiosk, then Electron.
# Disable OSK: Environment=THERMO_DISABLE_OSK=1 on the kiosk unit, or omit wvkbd package.
set -eu

WVK_LOG=/tmp/thermocline-wvkbd.log
LAUNCH_LOG=/tmp/thermocline-kiosk-launch.log

_log() {
	ts=$(date '+%Y-%m-%dT%H:%M:%S')
	printf '%s %s\n' "$ts" "$*" >>"$LAUNCH_LOG"
	if command -v logger >/dev/null 2>&1; then
		logger -t thermocline-kiosk "$*"
	fi
	printf '%s\n' "$*" >&2
}

app=/opt/thermocline-electron/thermocline-electron
if [ ! -x "$app" ]; then
	_log "missing executable: $app"
	exit 1
fi

_log "starting $app; WAYLAND_DISPLAY=${WAYLAND_DISPLAY-} XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR-}"

if [ "${THERMO_DISABLE_OSK:-0}" != 1 ]; then
	delay=${THERMO_WVKBD_DELAY_SEC:-4}
	[ "$delay" -ge 0 ] 2>/dev/null || delay=4
	# Do not `exec wvkbd` in a subshell whose parent becomes Electron — Electron never wait()s,
	# so wvkbd ends up <defunct>. Use `setsid -f` so the keyboard reparents to init and survives.
	(
		sleep "$delay"
		printf '\n---- %s wvkbd spawn WAYLAND=%s XDG=%s\n' \
			"$(date '+%Y-%m-%dT%H:%M:%S')" \
			"${WAYLAND_DISPLAY-}" "${XDG_RUNTIME_DIR-}" >>"$WVK_LOG"
		for c in wvkbd-mobintl wvkbd-mobile wvkbd-deskintl; do
			if ! command -v "$c" >/dev/null 2>&1; then
				continue
			fi
			# wvkbd 0.15+ (Debian trixie) removed --non-exclusive; older builds still support it.
			extra=
			if [ "${THERMO_WVKBD_EXCLUSIVE:-0}" != 1 ]; then
				if "$c" --help 2>/dev/null | grep -Fq -- '--non-exclusive'; then
					extra=--non-exclusive
				fi
			fi
			_log "spawning $c ${extra:+$extra }(stderr -> $WVK_LOG)"
			if command -v setsid >/dev/null 2>&1 && setsid -f true 2>/dev/null; then
				if [ -n "$extra" ]; then
					setsid -f "$c" $extra >>"$WVK_LOG" 2>&1 &
				else
					setsid -f "$c" >>"$WVK_LOG" 2>&1 &
				fi
			else
				if [ -n "$extra" ]; then
					nohup "$c" $extra >>"$WVK_LOG" 2>&1 &
				else
					nohup "$c" >>"$WVK_LOG" 2>&1 &
				fi
			fi
			exit 0
		done
		_log "no wvkbd-* in PATH (sudo apt install wvkbd)"
		printf '%s no wvkbd binary in PATH\n' "$(date '+%Y-%m-%dT%H:%M:%S')" >>"$WVK_LOG"
	) &
fi

exec "$app"
