const { app, BrowserWindow, ipcMain } = require('electron');
const path = require('node:path');

// Kiosk / Pi: Chromium uses large shared-memory segments; small /dev/shm can break GPU/zygote.
if (process.platform === 'linux') {
  app.commandLine.appendSwitch('disable-dev-shm-usage');
}

// Lazy-load serialport so the app starts even when the native bindings are missing (e.g. on Pi image)
let SerialPort = null;
let ReadlineParser = null;
function loadSerialModule() {
  if (SerialPort !== null) return true;
  try {
    const serialport = require('serialport');
    const readline = require('@serialport/parser-readline');
    SerialPort = serialport.SerialPort;
    ReadlineParser = readline.ReadlineParser;
    return true;
  } catch (e) {
    console.warn('Serial module unavailable (native bindings missing?):', e.message);
    return false;
  }
}

// Handle creating/removing shortcuts on Windows when installing/uninstalling.
if (require('electron-squirrel-startup')) {
  app.quit();
}

// Set THERMOCLINE_DEV=1 to lock window to 800x480 (final Pi display) for local testing
const isDevSize = process.env.THERMOCLINE_DEV === '1' || process.env.THERMOCLINE_DEV === 'true';

function serialTrace(...parts) {
  if (process.env.THERMO_SERIAL_TRACE !== '1' && process.env.THERMO_SERIAL_TRACE !== 'true') return;
  console.log('[serial-trace]', ...parts);
}

const createWindow = () => {
  const mainWindow = new BrowserWindow({
    width: isDevSize ? 800 : 1920,
    height: isDevSize ? 480 : 1080,
    fullscreen: !isDevSize,
    webPreferences: {
      preload: MAIN_WINDOW_PRELOAD_WEBPACK_ENTRY,
      nodeIntegration: false,
      contextIsolation: true,
    },
  });

  // and load the index.html of the app.
  mainWindow.loadURL(MAIN_WINDOW_WEBPACK_ENTRY);

  // Kiosk / Pi: zoom out to 60% so the UI fits the display
  mainWindow.webContents.once('did-finish-load', () => {
    mainWindow.webContents.setZoomFactor(0.65);
  });

  // Open the DevTools (comment out for production)
  // mainWindow.webContents.openDevTools();
};

// This method will be called when Electron has finished
// initialization and is ready to create browser windows.
// Some APIs can only be used after this event occurs.
app.whenReady().then(() => {
  createWindow();

  // On OS X it's common to re-create a window in the app when the
  // dock icon is clicked and there are no other windows open.
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

// Quit when all windows are closed, except on macOS. There, it's common
// for applications and their menu bar to stay active until the user quits
// explicitly with Cmd + Q.
app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

// Serial port management (non-fatal: app runs fine without serial)
let serialPort = null;
let parser = null;
let serialConnectInProgress = false;

function releaseSerialConnectLock() {
  serialConnectInProgress = false;
}

function notifySerialStatus(mainWindow, status, detail = null) {
  console.log('[serial]', 'status', status, detail != null ? detail : '');
  if (!mainWindow || mainWindow.isDestroyed()) return;
  try {
    mainWindow.webContents.send('serial-status', { status, detail });
    if (status === 'open-failed' || status === 'error') {
      mainWindow.webContents.send('serial-error', detail || status);
    }
  } catch (e) { /* ignore */ }
}

function clearSerialPort() {
  if (serialPort) {
    try {
      serialPort.removeAllListeners();
      serialPort.close(() => {});
    } catch (e) { /* ignore */ }
    serialPort = null;
    parser = null;
  }
}

// Auto-detect and connect to serial port (failure is non-fatal)
async function autoConnectSerial() {
  if (serialConnectInProgress) return null;
  serialConnectInProgress = true;
  const mainWindow = BrowserWindow.getAllWindows()[0];

  try {
    if (!loadSerialModule()) {
      console.warn('[serial] auto-connect skipped: serialport native module not available');
      notifySerialStatus(mainWindow, 'error', 'Serial module not available');
      releaseSerialConnectLock();
      return null;
    }

    const ports = await SerialPort.list();
    const listed = ports.map((p) => p.path).join(', ') || '(none)';
    console.log('[serial] enumerated ports:', listed);

    // Pi 4 UART2 (GPIO 0/1) only — no fallback to other ttyAMA* or USB serial.
    const desiredPorts = ['/dev/ttyAMA2'];
    let portPath = null;

    for (const commonPort of desiredPorts) {
      if (ports.some(p => p.path === commonPort)) {
        portPath = commonPort;
        break;
      }
    }
    if (!portPath) {
      console.warn('[serial] auto-connect: /dev/ttyAMA2 not in list (need dtoverlay=uart2 + dialout?)');
      notifySerialStatus(mainWindow, 'no-port', listed);
      releaseSerialConnectLock();
      return null;
    }

    serialPort = new SerialPort({
      path: portPath,
      baudRate: 115200,
      dataBits: 8,
      stopBits: 1,
      parity: 'none',
      autoOpen: false, // default true would race with open() below → "Port is opening"
    });

    parser = serialPort.pipe(new ReadlineParser({ delimiter: '\n' }));

    parser.on('data', (data) => {
      const dataStr = data.toString();
      serialTrace('RX', dataStr.replace(/\r?\n$/, '').slice(0, 500));
      const win = BrowserWindow.getAllWindows()[0];
      if (win && !win.isDestroyed()) {
        try {
          win.webContents.send('serial-data', dataStr + '\n');
        } catch (e) { /* ignore */ }
      }
    });

    parser.on('error', (err) => {
      console.warn('Serial parser warning:', err.message);
    });

    serialPort.open((err) => {
      if (err) {
        console.warn('Serial port unavailable (non-fatal):', err.message);
        clearSerialPort();
        notifySerialStatus(mainWindow, 'open-failed', err.message);
        releaseSerialConnectLock();
        return;
      }

      notifySerialStatus(mainWindow, 'connected', portPath);
      console.log('Serial connected on', portPath);
      if (mainWindow) mainWindow.webContents.send('serial-auto-connected', portPath);

      try {
        serialPort.set({ dtr: true, rts: false });
        setTimeout(() => {
          try {
            serialPort.set({ dtr: false });
            setTimeout(() => serialPort.set({ dtr: true }), 100);
          } catch (e) { /* ignore */ }
        }, 500);
        serialPort.flush(() => {});
      } catch (e) {
        console.warn('Serial signals warning:', e.message);
      }
      releaseSerialConnectLock();
    });

    serialPort.on('error', (err) => {
      console.warn('Serial port error (non-fatal):', err.message);
      notifySerialStatus(mainWindow, 'error', err.message);
      clearSerialPort();
      releaseSerialConnectLock();
    });

    serialPort.on('close', () => {
      serialPort = null;
      parser = null;
    });

    return portPath;
  } catch (err) {
    console.warn('Serial auto-connect failed (non-fatal):', err.message);
    notifySerialStatus(mainWindow, 'error', err.message);
    clearSerialPort();
    releaseSerialConnectLock();
    return null;
  }
}

// IPC handlers for serial port
ipcMain.handle('serial-connect', async (event, baudRate) => {
  if (!loadSerialModule()) {
    return { success: false, error: 'Serial module not available' };
  }
  if (serialPort && serialPort.isOpen) {
    return { success: true, port: serialPort.path };
  }

  const portPath = await autoConnectSerial();
  if (portPath && serialPort) {
    return { success: true, port: portPath };
  }
  return { success: false, error: 'Failed to connect to serial port' };
});

ipcMain.handle('serial-disconnect', async () => {
  if (serialPort) {
    return new Promise((resolve) => {
      serialPort.close((err) => {
        serialPort = null;
        parser = null;
        resolve({ success: !err });
      });
    });
  }
  return { success: true };
});

ipcMain.handle('serial-write', async (event, data) => {
  serialTrace('TX', String(data).slice(0, 500));
  if (serialPort && serialPort.isOpen) {
    return new Promise((resolve) => {
      serialPort.write(data + '\n', (err) => {
        resolve({ success: !err });
      });
    });
  }
  return { success: false };
});

ipcMain.handle('serial-is-connected', async () => {
  return serialPort && serialPort.isOpen;
});

// Auto-connect when app is ready (failure is non-fatal; app runs without serial)
app.whenReady().then(() => {
  setTimeout(() => autoConnectSerial(), 1000);
});

// In this file you can include the rest of your app's specific main process
// code. You can also put them in separate files and import them here.
