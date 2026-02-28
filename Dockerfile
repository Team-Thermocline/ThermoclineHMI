# rpi-image-gen in a container (Debian/Ubuntu env) so you can build on Arch or any host.
# Run build.sh; it will use this image when rpi-image-gen is not installed on the host.

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    && rm -rf /var/lib/apt/lists/*

# Clone rpi-image-gen; build expects it at /usr/share/rpi-image-gen
RUN git clone --depth 1 https://github.com/raspberrypi/rpi-image-gen.git /opt/rpi-image-gen \
    && ln -s /opt/rpi-image-gen /usr/share/rpi-image-gen

WORKDIR /opt/rpi-image-gen

# Install rpi-image-gen deps by hand (install_deps.sh requires binfmt_misc)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    bash coreutils python-is-python3 python3-yaml python3-debian dpkg-dev \
    mmdebstrap arch-test podman uidmap dbus-user-session zip dosfstools e2fsprogs \
    grep rsync curl mtools zstd pv btrfs-progs dctrl-tools uuid-runtime \
    util-linux fdisk python3-jsonschema python3-pip make build-essential \
    autoconf automake libtool autopoint flex gettext pkg-config \
    python3-ruamel.yaml qemu-user-static binfmt-support \
    && rm -rf /var/lib/apt/lists/*

# Allow unauthenticated/insecure apt so chroot apt-get update works without Debian keys
RUN sed -i '/--target .*IGconf_target_path/a\ _bdebstrap+=( --aptopt '\''APT::Get::AllowUnauthenticated "true"'\'' )' /opt/rpi-image-gen/rpi-image-gen \
    && sed -i '/--target .*IGconf_target_path/a\ _bdebstrap+=( --aptopt '\''Acquire::AllowInsecureRepositories "true"'\'' )' /opt/rpi-image-gen/rpi-image-gen \
    && sed -i '/--target .*IGconf_target_path/a\ _bdebstrap+=( --aptopt '\''Acquire::AllowDowngradeToInsecureRepositories "true"'\'' )' /opt/rpi-image-gen/rpi-image-gen

# Skip binfmt_misc check (container cannot bind-mount /proc; host binfmt is used at runtime with --privileged)
RUN sed -i 's|if ! grep -q "/proc/sys/fs/binfmt_misc"|if false \&\& ! grep -q "/proc/sys/fs/binfmt_misc"|' /opt/rpi-image-gen/lib/dependencies.sh

# Splash hook: use /root/ instead of /tmp/ so the file is visible inside chroot
RUN sed -i 's|TEMP_IMAGE="/tmp/splash-screen-source.tga"|TEMP_IMAGE="/root/splash-screen-source.tga"|' /opt/rpi-image-gen/layer/rpi/device/splash-screen/splash-screen.yaml

# Default: run rpi-image-gen (caller passes "build ..." etc.)
ENTRYPOINT ["/opt/rpi-image-gen/rpi-image-gen"]
CMD ["--help"]
