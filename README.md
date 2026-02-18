# Team Thermocline HMI

Raspberry Pi 4 (64-bit) image built with [Buildroot](https://buildroot.org/) **inside Docker**, so you don’t need to fix host toolchains (GCC/glibc) on your machine.

## Build (Docker)

Requires Docker. From the repo root:

```shell
./build.sh
```

Output will be in `output/sdcard.img`.

First run can take a long time (download + compile). Later runs reuse the image and Buildroot cache.

## Write image to SD card

```shell
sudo dd if=output/sdcard.img of=/dev/sdX status=progress bs=4M
sync
```

Replace `sdX` with your SD device (e.g. `sdb`).
