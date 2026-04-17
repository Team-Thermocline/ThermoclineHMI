const fs = require('fs');
const { execFileSync } = require('child_process');
const { FusesPlugin } = require('@electron-forge/plugin-fuses');
const { FuseV1Options, FuseVersion } = require('@electron/fuses');
const path = require('path');
const { rebuild } = require('@electron/rebuild');

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

/** Rebuild native deps in the staged app for the packager target (Electron ABI + platform/arch). */
function rebuildPackagedNativeModules(buildPath, electronVersion, platform, arch, callback) {
  const nm = path.join(buildPath, 'node_modules');
  if (!fs.existsSync(nm)) {
    return callback();
  }
  rebuild({ buildPath, electronVersion, arch, platform, force: true })
    .then(() => callback())
    .catch((err) => callback(err));
}

/** Fail linux/arm64 packages built on non-arm64 hosts if serialport binding is not aarch64 (prevents shipping x86 .node). */
function assertSerialportBindingMatchesLinuxArm64(buildPath, _electronVersion, platform, arch, callback) {
  if (platform !== 'linux' || arch !== 'arm64') {
    return callback();
  }
  if (process.platform === 'linux' && process.arch === 'arm64') {
    return callback();
  }
  const binding = path.join(
    buildPath,
    'node_modules',
    '@serialport',
    'bindings-cpp',
    'build',
    'Release',
    'bindings.node'
  );
  if (!fs.existsSync(binding)) {
    return callback(new Error(`[forge] Missing serialport binding (expected ${binding}). Use Docker or build on Pi.`));
  }
  let fileOut = '';
  try {
    fileOut = execFileSync('file', [binding], { encoding: 'utf8' });
  } catch (e) {
    console.warn('[forge] Could not run `file` to verify bindings.node arch:', e.message);
    return callback();
  }
  if (!/(aarch64|ARM aarch64|ARM arm64)/i.test(fileOut)) {
    return callback(
      new Error(
        `[forge] linux/arm64 build has non-aarch64 serialport binding (${process.platform}/${process.arch}). ` +
          `${fileOut.trim()}. Use ./build.sh or npm run package:pi:docker (see README).`
      )
    );
  }
  callback();
}

module.exports = {
  packagerConfig: {
    asar: true,
    asarUnpack: ['**/node_modules/**'],
    afterCopy: [
      copyProductionNodeModules,
      rebuildPackagedNativeModules,
      assertSerialportBindingMatchesLinuxArm64,
    ],
    executableName: 'thermocline-electron',
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
