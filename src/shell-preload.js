const { contextBridge } = require('electron');
const path = require('path');
const config = require('../config');

// ส่งค่า config ไปให้ shell.js (ทำงานในหน้าเปลือก) แบบปลอดภัย
contextBridge.exposeInMainWorld('maskConfig', {
  url: config.url,
  userAgent: config.userAgent,
  partition: 'persist:main',
  brand: config.displayName,
  chrome: config.chrome || { header: true, bottomNav: true },
  feed: config.feed || { enabled: false },
  hasLocation: !!config.location,
  // path แบบ file:// ของ preload ที่ใช้ spoof พิกัด GPS ใน webview
  geoPreload: 'file://' + path.join(__dirname, 'preload.js'),
});
