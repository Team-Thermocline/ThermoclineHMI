# Thermocline Electron

> A note from Joe
> 
> This part of the HMI packaging (and really the whole web process in general)
> involved a LOT of moving parts. Wherever possible i tried to pin packages and versions, but
> this is perhaps the most clunky part of the whole project.
>
> To whoever ends up reading this and trying to rebuild or get this working again, just consider
> the time when it was written. If pinned versions still exist, I'd probably reccomend using them
> or else, consider refactoring entirely! [tcode](https://github.com/Team-Thermocline/T-Code) was
> written for this purpose!
>
> Thank you!

# Building this app

## To start

Install deps
```shell
npm install
```

## Running dev

```shell
npm start
```

## Packaging

```shell
npm run package
```
   
The packaged app will be in `dist/thermocline-electron-linux-arm64/` (or `dist/thermocline-electron-linux-armv7l/` for 32-bit)

# Building for Raspberry Pi

## For 64-bit Raspberry Pi (Pi 3+, Pi 4, Pi 5):
```shell
npm run package:pi
```

The packaged app will be in `dist/thermocline-electron-linux-arm64/`

## Running on Raspberry Pi

After packaging, copy the entire directory from `dist/thermocline-electron-linux-arm64/` (or `armv7l`) to your Raspberry Pi, then run:
```bash
./thermocline-electron
```

Or create a DEB package for easier installation:
```bash
npm run make:pi
```

This creates a `.deb` file in `out/make/deb/arm64/` that can be installed with:
```bash
sudo dpkg -i thermocline-electron_*.deb
```
