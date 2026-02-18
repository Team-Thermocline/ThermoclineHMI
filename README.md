# Team Thermocline HMI

Built with [Buildroot](https://buildroot.org/) for Raspberry Pi 4 (64-bit). Buildroot is a git submodule in `buildroot/`.

## Build

```shell
./setup.sh
```

(Initializes the `buildroot` submodule if needed, then builds. First run takes a while.)

## Write to SD card

```shell
sudo dd if=buildroot/output/images/sdcard.img of=/dev/sdX status=progress bs=4M
sync
```