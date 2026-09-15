// ─────────────────────────────────────────────────────────────
//  ตั้งค่าการ "อำพราง" (disguise) ทั้งหมดอยู่ตรงนี้
//  All disguise settings live here.
// ─────────────────────────────────────────────────────────────
module.exports = {
  // ชื่อที่จะโชว์บน Dock / เมนูบาร์ / Notification
  // The name shown on the Dock / menu bar / notifications.
  // NOTE: ตอน build แพ็กเกจ ให้แก้ "productName" ใน package.json ให้ตรงกันด้วย
  displayName: 'Instagram',

  // หน้าที่จะเปิดจริง ๆ (Tinder web)
  url: 'https://tinder.com/app/recs',

  // ใช้ User-Agent ของ Chrome เดสก์ท็อป เพื่อให้ Tinder เสิร์ฟเว็บแอปเต็มรูปแบบ
  userAgent:
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 ' +
    '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',

  // พิกัด GPS แบบ fix ไว้ (Tinder ต้องใช้ location).
  // null = ใช้ตำแหน่งจริงของเครื่อง (ต้องมี GOOGLE_API_KEY ดู README)
  // ตัวอย่างกรุงเทพ: { latitude: 13.7563, longitude: 100.5018 }
  location: null,

  // ขนาดหน้าต่าง (Tinder web เป็นเลย์เอาต์แนวตั้งคล้ายมือถือ)
  // เผื่อความสูงให้หัวโพสต์ + แถวปุ่มของโหมดฟีดด้วย
  window: { width: 480, height: 900 },

  // หน้าตา "เปลือก" (shell UI) ที่ครอบ Tinder ไว้
  chrome: {
    header: true,      // แถบบนสไตล์ Instagram
    bottomNav: true,   // แถบล่าง 5 ไอคอนแบบ IG (ตกแต่งเพื่ออำพราง)
  },

  // โหมด "ฟีด IG" — ทำให้การ์ด Tinder ใช้งานเหมือนโพสต์ใน Instagram
  feed: {
    enabled: true,          // เปิดเปลือกโพสต์ (post header + action row แบบ IG)
    doubleTapLike: true,    // ดับเบิลแท็ปรูป = Like พร้อมหัวใจเด้งแบบ IG
    scrollToPass: true,     // เลื่อนลงแรง ๆ = ข้ามคนนี้ (Nope) เหมือนเลื่อนผ่านโพสต์
    hideTinderButtons: true, // ซ่อนแถวปุ่ม Rewind/Nope/Like เดิมของ Tinder (ปุ่มของเปลือกยังสั่งงานได้ปกติ)
  },
};
