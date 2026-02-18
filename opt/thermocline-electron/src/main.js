const { app, BrowserWindow, ipcMain } = require('electron');
const path = require('node:path');
const { SerialPort } = require('serialport');
const { ReadlineParser } = require('@serialport/parser-readline');

// Handle creating/removing shortcuts on Windows when installing/uninstalling.
if (require('electron-squirrel-startup')) {
  app.quit();
}

const createWindow = () => {
  // Create the browser window.
  const mainWindow = new BrowserWindow({
    width: 1920,
    height: 1080,
    fullscreen: true,
    webPreferences: {
      preload: MAIN_WINDOW_PRELOAD_WEBPACK_ENTRY,
      nodeIntegration: false,
      contextIsolation: true,
    },
  });

  // and load the index.html of the app.
  mainWindow.loadURL(MAIN_WINDOW_WEBPACK_ENTRY);

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

// Serial port management
let serialPort = null;
let parser = null;

// Auto-detect and connect to serial port
async function autoConnectSerial() {
  try {
    // List all
    const ports = await SerialPort.list();
    
    // On final system, only one tty should be avail
    const desiredPorts = ['/dev/ttyUSB0', '/dev/ttyACM0', '/dev/ttyUSB1', '/dev/ttyACM1'];
    let portPath = null;
    
    // Try and match port
    for (const commonPort of desiredPorts) {
      if (ports.some(p => p.path === commonPort)) {
        portPath = commonPort;
        break;
      }
    }
    
    // If no common port found, use the first available port as a fallback/testing
    if (!portPath && ports.length > 0) {
      portPath = ports[0].path;
    }
    
    if (!portPath) {
      console.log('No serial ports found');
      return null;
    }
    
    console.log(`Auto-connecting to serial port: ${portPath}`);
    
    // Create serial port connection
    serialPort = new SerialPort({
      path: portPath,
      baudRate: 115200,
      dataBits: 8,
      stopBits: 1,
      parity: 'none',
    });
    
    // Create parser for reading lines
    parser = serialPort.pipe(new ReadlineParser({ delimiter: '\n' }));
    
    // Handle data
    parser.on('data', (data) => {
      const mainWindow = BrowserWindow.getAllWindows()[0];
      if (mainWindow) {
        mainWindow.webContents.send('serial-data', data.toString());
      }
    });
    
    // Handle errors
    serialPort.on('error', (err) => {
      console.error('Serial port error:', err);
      const mainWindow = BrowserWindow.getAllWindows()[0];
      if (mainWindow) {
        mainWindow.webContents.send('serial-error', err.message);
      }
    });
    
    serialPort.on('close', () => {
      console.log('Serial port closed');
      serialPort = null;
      parser = null;
    });
    
    return portPath;
  } catch (err) {
    console.error('Error auto-connecting to serial port:', err);
    return null;
  }
}

// IPC handlers for serial port
ipcMain.handle('serial-connect', async (event, baudRate) => {
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

// Auto-connect when app is ready
app.whenReady().then(() => {
  // Small delay to ensure window is created
  setTimeout(() => {
    autoConnectSerial().then((portPath) => {
      if (portPath) {
        const mainWindow = BrowserWindow.getAllWindows()[0];
        if (mainWindow) {
          mainWindow.webContents.send('serial-auto-connected', portPath);
        }
      }
    });
  }, 1000);
});

// In this file you can include the rest of your app's specific main process
// code. You can also put them in separate files and import them here.
