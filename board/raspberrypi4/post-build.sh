#!/bin/sh
# Post-build script for Thermocline Raspberry Pi 4 builds
# Merges Electron app installation with opt/ directory overlay

set -e

# Buildroot sets TARGET_DIR. Derive paths from it.
BR_DIR="$(cd "$(dirname "$(dirname "$TARGET_DIR")")" && pwd)"
REPO_ROOT="$(cd "$BR_DIR/.." && pwd)"

# Run Raspberry Pi 4 board post-build (HDMI console etc.) if it exists
# Check for both 32-bit and 64-bit board scripts
if [ -f "$BR_DIR/board/raspberrypi4/post-build.sh" ]; then
    echo "Running Raspberry Pi 4 board post-build script..."
    sh "$BR_DIR/board/raspberrypi4/post-build.sh"
elif [ -f "$BR_DIR/board/raspberrypi4-64/post-build.sh" ]; then
    echo "Running Raspberry Pi 4-64 board post-build script..."
    sh "$BR_DIR/board/raspberrypi4-64/post-build.sh"
fi

# Overlay repo opt/ onto rootfs (files here end up in the image root)
# This preserves the existing behavior from scripts/post-build.sh
if [ -d "$REPO_ROOT/opt" ]; then
    echo "Overlaying opt/ directory..."
    for f in "$REPO_ROOT"/opt/*; do
        [ -e "$f" ] || continue
        cp -a "$f" "$TARGET_DIR/"
    done
fi

# Install Electron app if it exists (path relative to buildroot topdir)
# Check for both arm64 and armv7l builds
if [ -d "${TOPDIR}/../opt/thermocline-electron/dist/thermocline-electron-linux-arm64" ]; then
    echo "Installing Thermocline Electron app (arm64)..."
    mkdir -p "${TARGET_DIR}/opt/thermocline-electron"
    cp -r "${TOPDIR}/../opt/thermocline-electron/dist/thermocline-electron-linux-arm64"/* \
        "${TARGET_DIR}/opt/thermocline-electron/"
    chmod +x "${TARGET_DIR}/opt/thermocline-electron/thermocline-electron"
elif [ -d "${TOPDIR}/../opt/thermocline-electron/dist/thermocline-electron-linux-armv7l" ]; then
    echo "Installing Thermocline Electron app (armv7l)..."
    mkdir -p "${TARGET_DIR}/opt/thermocline-electron"
    cp -r "${TOPDIR}/../opt/thermocline-electron/dist/thermocline-electron-linux-armv7l"/* \
        "${TARGET_DIR}/opt/thermocline-electron/"
    chmod +x "${TARGET_DIR}/opt/thermocline-electron/thermocline-electron"
fi

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
