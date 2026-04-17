# Thermocline Electron

> A note from Joe
> 
> This part of the HMI packaging (and really the whole web process in general)
> involved a LOT of moving parts. Wherever possible i tried to pin packages and versions, but
> this is perhaps the most clunky part of the whole project.
>
> To whoever ends up reading this and trying to rebuild or get this working again, just consider
> the time when it was written. If pinned versions still exist, I'd probably recommend using them
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

To test at the Pi display size (800×480), use:

```shell
npm run start:dev
```

(This sets `THERMOCLINE_DEV=1`; window is 800×480, not fullscreen.)

## Packaging

```shell
npm run package
```

Output is under **`out/<name>-<platform>-<arch>/`** (Forge default).

# Building for Raspberry Pi (64-bit)

Do **not** run `npm run package:pi` on **x86_64** and deploy to the Pi (you will ship an **x86-64** `bindings.node` and serial will fail). Use **Docker** or build on **linux/arm64** (the Pi).

- **On the Pi / arm64 Linux:** `cd thermocline-electron && npm ci && npm run package:pi`
- **From other hosts:** once if needed: `docker run --rm --privileged tonistiigi/binfmt --install all`  
  then repo **`./build.sh`** or `npm run package:pi:docker` (uses **`tmpfs`** for `node_modules` inside the arm64 container so the host tree is not reused).

Forge **`@electron/rebuild`** + a **`file`** check on staged `bindings.node` catch mistaken x86→arm64 packages when not building in Docker/Pi.

**Output:** `out/thermocline-electron-linux-arm64/` (32-bit: `out/thermocline-electron-linux-armv7l/`).

## Running on Raspberry Pi

After packaging, copy the entire directory from `out/thermocline-electron-linux-arm64/` (or `armv7l`) to your Raspberry Pi, then run:
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
