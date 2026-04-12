// See the Electron documentation for details on how to use preload scripts:
// https://www.electronjs.org/docs/latest/tutorial/process-model#preload-scripts

const { contextBridge, ipcRenderer } = require('electron');

// Expose serial port API to renderer
contextBridge.exposeInMainWorld('electronSerial', {
  connect: (baudRate) => ipcRenderer.invoke('serial-connect', baudRate),
  disconnect: () => ipcRenderer.invoke('serial-disconnect'),
  write: (data) => ipcRenderer.invoke('serial-write', data),
  isConnected: () => ipcRenderer.invoke('serial-is-connected'),
  onData: (callback) => {
    // Remove any existing listeners first to avoid duplicates
    ipcRenderer.removeAllListeners('serial-data');
    ipcRenderer.on('serial-data', (event, data) => {
      try {
        callback(data);
      } catch (err) {
        console.error('Error in data callback:', err);
      }
    });
  },
  onError: (callback) => {
    ipcRenderer.removeAllListeners('serial-error');
    ipcRenderer.on('serial-error', (event, error) => callback(error));
  },
  onAutoConnected: (callback) => {
    ipcRenderer.removeAllListeners('serial-auto-connected');
    ipcRenderer.on('serial-auto-connected', (event, portPath) => callback(portPath));
  },
  removeAllListeners: (channel) => {
    ipcRenderer.removeAllListeners(channel);
  },
});
