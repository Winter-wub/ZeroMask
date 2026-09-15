# Instagram (iOS) — Tinder wrapper แบบฟีด IG

พอร์ตจากเวอร์ชัน desktop (Electron) มาเป็นแอป iOS เนทีฟ (SwiftUI + WKWebView)
หน้าตา/ท่าทาง/ฟังก์ชันเหมือนกันทุกอย่าง:

- เปลือก Instagram (header, หัวโพสต์, แถวปุ่ม, แถบล่าง 5 ปุ่ม)
- ดับเบิลแท็ปรูป = Like (หัวใจเด้ง), ปัดขึ้นแรง ๆ = ข้ามคนนี้
- 🔍 = Explore, 💬 = แชท, ❤️ แถบล่าง = Likes You, ⭕ = โปรไฟล์
- ลอก UI ของ Tinder ออก (nav แบรนด์ + แถวปุ่ม gamepad) เหลือแค่รูป
- ชื่อ+อายุจากการ์ดจริงขึ้นหัวโพสต์
- ชื่อ/ไอคอนบนเครื่องเป็น "Instagram"

## PIN 2 ชุด (หลัก + สำรอง)

ตั้งใน **การตั้งค่า** (ปุ่ม `···` มุมขวาบน):

| ชุด | ใส่ที่หน้าล็อกแล้วได้อะไร |
|-----|---------------------------|
| **PIN หลัก** (หัวข้อ "ความปลอดภัย") | เข้าแอปตามปกติ (เปลือก IG ครอบ Tinder) |
| **PIN สำรอง** (หัวข้อ "PIN สำรอง") | เปิดเว็บ PickleWatch **ตัวจริง** เต็มจอ ไม่เห็นแอปข้างในเลย |

- PIN สำรองตั้งได้ต่อเมื่อเปิด PIN หลักไว้แล้ว และห้ามตั้งซ้ำกับ PIN หลัก
- ลิงก์ถ่ายทอดสดแก้ได้ในหน้าเดียวกัน (ดีฟอลต์
  ว่างไว้ ต้องใส่ลิงก์เองในหน้า Settings)
- ออกจากโหมด PIN สำรอง: **แตะมุมซ้ายบน 5 ครั้งติด ๆ** → กลับหน้าล็อกเพื่อใส่ PIN หลัก
  (สลับแอปออกไปก็ออกจากโหมดนี้เหมือนกัน)
- webview ของโหมดนี้ใช้ session แบบไม่จำ (non-persistent) แยกจาก Tinder/Instagram

## ติดตั้งลงเครื่อง (ทำครั้งเดียว)

**1. เปิด Developer Mode บน iPhone**
   Settings → Privacy & Security → Developer Mode → เปิด → รีสตาร์ทเครื่อง

**2. เพิ่ม Apple ID ใน Xcode** (โปรเจกต์เปิดค้างไว้แล้ว)
   Xcode → Settings (⌘,) → Accounts → ปุ่ม + → Apple ID → ล็อกอิน
   จากนั้นแท็บ Signing & Capabilities ของ target ควรขึ้น "Instagram" ทีมของคุณ

**3. เสียบสาย iPhone เข้า Mac** (หรืออยู่ WiFi วงเดียวกัน)

**4. กด Run (▶︎) ใน Xcode** — เลือกเครื่อง iPhone's Wave ด้านบน
   หรือรันจาก terminal:  `./install.sh`

**5. เชื่อถือ developer** (ครั้งแรกเท่านั้น)
   บนเครื่อง: Settings → General → VPN & Device Management → แตะชื่อ dev → Trust

## หมายเหตุ

- ใช้ free provisioning ได้ (ไม่ต้องจ่าย $99) แต่แอปจะหมดอายุทุก **7 วัน**
  ต้องกด Run/`./install.sh` ใหม่เพื่อต่ออายุ — ถ้าจ่าย Apple Developer จะได้ 1 ปี
- session/login ของ Tinder เก็บในเครื่อง (WKWebsiteDataStore) ล็อกอินครั้งเดียวจำไว้
- location ใช้ GPS จริงของ iPhone (Tinder ขอ permission เอง) — เนียนกว่า desktop
