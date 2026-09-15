// spoof ตำแหน่ง GPS ให้ Tinder ถ้ามีการตั้งค่า config.location ไว้
// (ทำงานได้เพราะ main.js ปิด contextIsolation เมื่อมี location)
const { ipcRenderer } = require('electron');
const config = require('../config');

if (config.location && typeof navigator !== 'undefined' && navigator.geolocation) {
  const fixed = {
    coords: {
      latitude: config.location.latitude,
      longitude: config.location.longitude,
      accuracy: 20,
      altitude: null,
      altitudeAccuracy: null,
      heading: null,
      speed: null,
    },
    timestamp: Date.now(),
  };

  navigator.geolocation.getCurrentPosition = (success) => {
    try { success(fixed); } catch (_) {}
  };
  navigator.geolocation.watchPosition = (success) => {
    try { success(fixed); } catch (_) {}
    return 0;
  };
  navigator.geolocation.clearWatch = () => {};
}

// ── โหมดฟีด IG: ดักท่าทาง (gesture) ในหน้า Tinder แล้วส่งบอกเปลือก ──
// ทุกอย่างต้องมาจากการกดของผู้ใช้เอง 1 ครั้ง = 1 แอ็กชัน (ไม่มีออโต้สไวป์)
const feed = config.feed || {};
if (feed.enabled && typeof window !== 'undefined') {
  const onTinder = () => location.hostname.endsWith('tinder.com');
  const onRecs = () => onTinder() && location.pathname.startsWith('/app/recs');

  // ดับเบิลแท็ปบนรูป → Like (เปลือกจะเด้งหัวใจ + ส่งคีย์ลัด Like ให้)
  if (feed.doubleTapLike) {
    document.addEventListener('dblclick', (e) => {
      if (!onRecs()) return;
      // อย่าไปยุ่งกับปุ่ม/ลิงก์/ช่องพิมพ์ (เช่นดับเบิลคลิกเลือกคำในแชท)
      if (e.target.closest('button, a, input, textarea, [contenteditable]')) return;
      ipcRenderer.sendToHost('mask:double-tap');
    }, true);
  }

  // เลื่อนลงแรง ๆ (เหมือนเลื่อนผ่านโพสต์) → ข้ามคนนี้ (Nope)
  // มี threshold + cooldown กันเลื่อนโดนคนถัดไปโดยไม่ตั้งใจ
  if (feed.scrollToPass) {
    let acc = 0;
    let coolUntil = 0;
    window.addEventListener('wheel', (e) => {
      if (!onRecs()) return;
      const now = Date.now();
      if (now < coolUntil) return;
      if (e.deltaY < 0) { acc = 0; return; } // เลื่อนขึ้น = ยกเลิกการสะสม
      acc += e.deltaY;
      if (acc >= 420) {
        acc = 0;
        coolUntil = now + 1400;
        ipcRenderer.sendToHost('mask:scroll-next');
      }
    }, { passive: true });
  }

  // อ่านชื่อ+อายุจากการ์ดที่โชว์อยู่ ส่งไปโชว์เป็น "username" หัวโพสต์
  // Tinder ใส่ microdata [itemprop=name]/[itemprop=age] ไว้บนการ์ด แต่มี
  // การ์ดถัดไปพรีโหลดซ้อนอยู่ → หาใบบนสุดด้วย elementFromPoint ตรงโซนชื่อ
  let lastName = '';
  setInterval(() => {
    if (!onRecs()) return;
    let el = document.elementFromPoint(Math.floor(innerWidth / 2), innerHeight - 90);
    while (el && el !== document.body && !(el.querySelector && el.querySelector('[itemprop="name"]'))) {
      el = el.parentElement;
    }
    if (!el || el === document.body) return;
    const nameEl = el.querySelector('[itemprop="name"]');
    const ageEl = el.querySelector('[itemprop="age"]');
    const name = nameEl ? nameEl.textContent.trim() : '';
    const age = ageEl ? ageEl.textContent.trim() : '';
    const label = name + (age ? ' · ' + age : '');
    if (name && label !== lastName) {
      lastName = label;
      ipcRenderer.sendToHost('mask:profile', label);
    }
  }, 1000);
}
