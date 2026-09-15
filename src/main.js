const { app, BrowserWindow, session, shell } = require('electron');
const path = require('path');
const config = require('../config');

// อำพรางชื่อแอปให้เร็วที่สุด (มีผลกับเมนูบาร์ + notification)
app.setName(config.displayName);

const PARTITION = 'persist:main'; // ทำให้ล็อกอินค้างไว้ ไม่ต้องล็อกอินใหม่ทุกครั้ง
let mainWindow;

function configureSession() {
  const ses = session.fromPartition(PARTITION);
  ses.setUserAgent(config.userAgent);

  // อนุญาตเฉพาะ permission ที่ Tinder ต้องใช้จริง ๆ
  const allowed = new Set([
    'geolocation',
    'notifications',
    'media', // กล้อง/ไมค์ (อัปรูป/วิดีโอ)
    'clipboard-read',
    'clipboard-sanitized-write',
  ]);
  ses.setPermissionRequestHandler((_wc, permission, callback) => {
    callback(allowed.has(permission));
  });
  ses.setPermissionCheckHandler((_wc, permission) => allowed.has(permission));
  return ses;
}

function createWindow() {
  configureSession();

  mainWindow = new BrowserWindow({
    width: config.window.width,
    height: config.window.height,
    title: config.displayName,
    icon: path.join(__dirname, '..', 'assets', 'icon.png'),
    backgroundColor: '#ffffff',
    titleBarStyle: 'hiddenInset', // ซ่อนแถบ title เดิม ให้ header IG ของเราขึ้นเต็ม
    webPreferences: {
      partition: PARTITION,
      preload: path.join(__dirname, 'shell-preload.js'),
      webviewTag: true, // เปิดให้ใช้ <webview> ฝัง Tinder
      contextIsolation: true,
      sandbox: false,
      nodeIntegration: false,
      spellcheck: false,
    },
  });

  // โหลด "เปลือก" (shell) ที่เป็นไฟล์ในเครื่อง แล้วไปฝัง Tinder ข้างใน
  mainWindow.loadFile(path.join(__dirname, 'shell.html'));

  // กันเปลี่ยน title ของหน้าต่าง (รักษาการอำพราง)
  mainWindow.on('page-title-updated', (e) => {
    e.preventDefault();
    mainWindow.setTitle(config.displayName);
  });
}

// จัดการ popup ของ <webview> (เช่น login Google/FB/Apple)
app.on('web-contents-created', (_e, contents) => {
  if (contents.getType() !== 'webview') return;
  contents.setWindowOpenHandler(({ url }) => {
    if (/(facebook\.com|accounts\.google\.com|appleid\.apple\.com|tinder\.com)/.test(url)) {
      return { action: 'allow' };
    }
    shell.openExternal(url);
    return { action: 'deny' };
  });
});

app.whenReady().then(() => {
  createWindow();
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
