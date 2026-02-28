# Thermocline HMI

Raspberry Pi image for the Thermocline thermal testing chamber HMI. The image boots into a **web kiosk** showing the **Sender** UI from [team-thermocline.github.io](https://github.com/Team-Thermocline/team-thermocline.github.io).

## Build

Requires Docker. Once per host, load binfmt so the cross-build (x86_64 → arm64) can run:

```bash
sudo modprobe binfmt_misc
```

Then:

```bash
./build.sh
```

Packs the web app, builds the Pi image in a container. Output: `output/sdcard.img`.
