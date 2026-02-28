const fs = require('fs');
const { FusesPlugin } = require('@electron-forge/plugin-fuses');
const { FuseV1Options, FuseVersion } = require('@electron/fuses');
const path = require('path');

// Copy runtime node_modules into packaged app (webpack externals aren't copied by forge).
// Copying the full production dependency tree avoids "Cannot find module 'x'" from transitive deps.
function cpRecursive(src, dest) {
  const st = fs.statSync(src, { throwIfNoEntry: false });
  if (!st) return;
  if (st.isSymbolicLink()) {
    try {
      const target = fs.readlinkSync(src);
      fs.symlinkSync(target, dest);
    } catch {
      // ignore broken symlinks (e.g. .bin)
        }
    return;
  }
  if (st.isDirectory()) {
    fs.mkdirSync(dest, { recursive: true });
    for (const name of fs.readdirSync(src)) {
      if (name === '.bin') continue; // skip .bin to avoid symlink issues and save space
      cpRecursive(path.join(src, name), path.join(dest, name));
    }
  } else {
    fs.copyFileSync(src, dest);
  }
}

function copyProductionNodeModules(buildPath, _electronVersion, _platform, _arch, callback) {
  const srcDir = path.join(__dirname, 'node_modules');
  const destDir = path.join(buildPath, 'node_modules');
  if (!fs.existsSync(srcDir)) {
    return callback();
  }
  try {
    const pkg = JSON.parse(fs.readFileSync(path.join(__dirname, 'package.json'), 'utf8'));
    const devDeps = new Set(Object.keys(pkg.devDependencies || {}));
    fs.mkdirSync(destDir, { recursive: true });
    for (const name of fs.readdirSync(srcDir)) {
      if (name === '.bin') continue;
      // Skip devDependencies to keep package smaller (electron, webpack, svelte, etc.)
      if (!name.startsWith('@') && devDeps.has(name)) continue;
      if (name.startsWith('@')) {
        const scopePath = path.join(srcDir, name);
        if (!fs.statSync(scopePath, { throwIfNoEntry: false })?.isDirectory()) continue;
        fs.mkdirSync(path.join(destDir, name), { recursive: true });
        for (const sub of fs.readdirSync(scopePath)) {
          const pkgName = `${name}/${sub}`;
          if (devDeps.has(pkgName)) continue;
          cpRecursive(path.join(scopePath, sub), path.join(destDir, name, sub));
        }
        continue;
      }
      const src = path.join(srcDir, name);
      if (fs.statSync(src, { throwIfNoEntry: false })?.isDirectory()) {
        cpRecursive(src, path.join(destDir, name));
      }
    }
  } catch (err) {
    return callback(err);
  }
  callback();
}

// Packaging: Forge + webpack packs only the bundle; runtime deps (serialport, debug, etc.)
// are copied in afterCopy and unpacked from asar so native .node bindings load.
// Alternative: asar: false avoids unpack issues but app dir is larger and easier to tamper with.
// Or: electron-builder has different native-module handling if you ever migrate.
module.exports = {
  packagerConfig: {
    asar: true,
    asarUnpack: ['**/node_modules/**'],
    afterCopy: [copyProductionNodeModules],
    // Output directory for packaged app
    out: path.resolve(__dirname, 'dist'),
    // Executable name
    executableName: 'thermocline-electron',
    // Default platform/arch (can be overridden via CLI flags)
    // Defaults to current platform, use --platform=linux --arch=arm64 for Pi
  },
  rebuildConfig: {},
  makers: [
    {
      name: '@electron-forge/maker-squirrel',
      config: {},
      platforms: ['win32'],
    },
    {
      name: '@electron-forge/maker-zip',
      platforms: ['darwin'],
    },
    {
      name: '@electron-forge/maker-deb',
      config: {
        options: {
          maintainer: 'Team Thermocline',
          homepage: 'https://team-thermocline.github.io/',
        },
      },
      platforms: ['linux'],
    },
    {
      name: '@electron-forge/maker-rpm',
      config: {},
      platforms: ['linux'],
    },
  ],
  plugins: [
    {
      name: '@electron-forge/plugin-auto-unpack-natives',
      config: {},
    },
    {
      name: '@electron-forge/plugin-webpack',
      config: {
        mainConfig: './webpack.main.config.js',
        renderer: {
          config: './webpack.renderer.config.js',
          entryPoints: [
            {
              html: './src/index.html',
              js: './src/renderer.js',
              name: 'main_window',
              preload: {
                js: './src/preload.js',
              },
            },
          ],
        },
      },
    },
    // Fuses are used to enable/disable various Electron functionality
    // at package time, before code signing the application
    new FusesPlugin({
      version: FuseVersion.V1,
      [FuseV1Options.RunAsNode]: false,
      [FuseV1Options.EnableCookieEncryption]: true,
      [FuseV1Options.EnableNodeOptionsEnvironmentVariable]: false,
      [FuseV1Options.EnableNodeCliInspectArguments]: false,
      [FuseV1Options.EnableEmbeddedAsarIntegrityValidation]: true,
      [FuseV1Options.OnlyLoadAppFromAsar]: true,
    }),
  ],
};
