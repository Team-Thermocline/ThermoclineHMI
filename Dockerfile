# Buildroot build environment
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    bc \
    bison \
    bzip2 \
    ca-certificates \
    cpio \
    file \
    flex \
    g++ \
    gawk \
    gcc \
    gettext \
    git \
    gzip \
    libncurses-dev \
    make \
    patch \
    perl \
    python3 \
    rsync \
    tar \
    unzip \
    wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work
