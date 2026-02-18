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
    ipcRenderer.on('serial-data', (event, data) => callback(data));
  },
  onError: (callback) => {
    ipcRenderer.on('serial-error', (event, error) => callback(error));
  },
  onAutoConnected: (callback) => {
    ipcRenderer.on('serial-auto-connected', (event, portPath) => callback(portPath));
  },
  removeAllListeners: (channel) => {
    ipcRenderer.removeAllListeners(channel);
  },
});
