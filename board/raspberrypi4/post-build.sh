#!/bin/sh
# Post-build script for Thermocline Raspberry Pi 4 builds
# Merges Electron app installation with opt/ directory overlay

set -e

# Buildroot sets TARGET_DIR. Derive paths from it.
BR_DIR="$(cd "$(dirname "$(dirname "$TARGET_DIR")")" && pwd)"
REPO_ROOT="$(cd "$BR_DIR/.." && pwd)"

# KDrive builds the X server as "X" (or Xfbdev); the package's xorg.service expects /usr/bin/Xorg.
# Create a symlink so xorg.service finds the binary.
if [ ! -x "$TARGET_DIR/usr/bin/Xorg" ] && [ -x "$TARGET_DIR/usr/bin/X" ]; then
    echo "Linking /usr/bin/Xorg -> X for xorg.service"
    ln -sf X "$TARGET_DIR/usr/bin/Xorg"
elif [ ! -x "$TARGET_DIR/usr/bin/Xorg" ] && [ -x "$TARGET_DIR/usr/bin/Xfbdev" ]; then
    echo "Linking /usr/bin/Xorg -> Xfbdev for xorg.service"
    ln -sf Xfbdev "$TARGET_DIR/usr/bin/Xorg"
fi

# Run Raspberry Pi 4 board post-build (HDMI console etc.) if it exists
# Check for both 32-bit and 64-bit board scripts
if [ -f "$BR_DIR/board/raspberrypi4/post-build.sh" ]; then
    echo "Running Raspberry Pi 4 board post-build script..."
    sh "$BR_DIR/board/raspberrypi4/post-build.sh"
elif [ -f "$BR_DIR/board/raspberrypi4-64/post-build.sh" ]; then
    echo "Running Raspberry Pi 4-64 board post-build script..."
    sh "$BR_DIR/board/raspberrypi4-64/post-build.sh"
fi

# Overlay repo opt/ into rootfs /opt (skip thermocline-electron – we install the packaged app only)
if [ -d "$REPO_ROOT/opt" ]; then
    echo "Overlaying opt/ into rootfs /opt..."
    mkdir -p "$TARGET_DIR/opt"
    for f in "$REPO_ROOT"/opt/*; do
        [ -e "$f" ] || continue
        [ "$(basename "$f")" = "thermocline-electron" ] && continue
        cp -a "$f" "$TARGET_DIR/opt/"
    done
fi

# Install packaged Electron app only. Prefer arm64; check dist/ and out/. Nuke existing so no source tree remains.
ELEC_ROOT="${REPO_ROOT}/opt/thermocline-electron"
for sub in dist/thermocline-electron-linux-arm64 out/thermocline-electron-linux-arm64 \
           dist/thermocline-electron-linux-armv7l out/thermocline-electron-linux-armv7l; do
    if [ -d "${ELEC_ROOT}/${sub}" ]; then
        echo "Installing Thermocline Electron app from ${sub}..."
        rm -rf "${TARGET_DIR}/opt/thermocline-electron"
        mkdir -p "${TARGET_DIR}/opt/thermocline-electron"
        cp -r "${ELEC_ROOT}/${sub}"/* "${TARGET_DIR}/opt/thermocline-electron/"
        chmod +x "${TARGET_DIR}/opt/thermocline-electron/thermocline-electron"
        break
    fi
done

# Enable systemd services
if [ -f "${TARGET_DIR}/etc/systemd/system/thermocline-electron.service" ]; then
    mkdir -p "${TARGET_DIR}/etc/systemd/system/graphical.target.wants"
    ln -sf /etc/systemd/system/thermocline-electron.service \
        "${TARGET_DIR}/etc/systemd/system/graphical.target.wants/thermocline-electron.service"
fi

if [ -f "${TARGET_DIR}/etc/systemd/system/xserver.service" ]; then
    mkdir -p "${TARGET_DIR}/etc/systemd/system/graphical.target.wants"
    ln -sf /etc/systemd/system/xserver.service \
        "${TARGET_DIR}/etc/systemd/system/graphical.target.wants/xserver.service"
fi

# So X can use vt1 (HDMI), mask getty on tty1 so the display shows X
if [ -d "${TARGET_DIR}/etc/systemd/system/getty.target.wants" ]; then
    rm -f "${TARGET_DIR}/etc/systemd/system/getty.target.wants/getty@tty1.service"
fi
ln -sf /dev/null "${TARGET_DIR}/etc/systemd/system/getty@tty1.service"

# Enable SSH for debugging
if [ -f "${TARGET_DIR}/usr/lib/systemd/system/sshd.service" ]; then
    mkdir -p "${TARGET_DIR}/etc/systemd/system/multi-user.target.wants"
    ln -sf /usr/lib/systemd/system/sshd.service \
        "${TARGET_DIR}/etc/systemd/system/multi-user.target.wants/sshd.service"
fi

# Create .xinitrc to start Electron when X starts
mkdir -p "${TARGET_DIR}/root"
cat > "${TARGET_DIR}/root/.xinitrc" << 'EOF'
#!/bin/sh
/opt/thermocline-electron/thermocline-electron
EOF
chmod +x "${TARGET_DIR}/root/.xinitrc"
