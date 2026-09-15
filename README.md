# mask-of-sex

Desktop wrapper ที่ห่อ **Tinder web** (`tinder.com`) ไว้ในแอป Electron แต่
อำพรางชื่อ + ไอคอนให้ดูเหมือนแอปอื่น (เช่น Instagram) — เปิดมาเหมือนเล่น IG
แต่ข้างในคือ Tinder จริง ๆ

> ใช้สำหรับเครื่องตัวเองเท่านั้น เป็นแค่การห่อเว็บ ไม่มีบอท/ไม่ออโต้สไวป์
> (การออโต้สไวป์ผิด ToS ของ Tinder)

## รัน (โหมด dev)

```bash
npm install      # ครั้งแรกครั้งเดียว
npm start
```

หน้าต่างจะเปิด `tinder.com` ขึ้นมา ล็อกอินครั้งเดียว session จะถูกจำไว้
(เก็บใน `~/Library/Application Support/<displayName>`)

## ปรับการอำพราง

แก้ไฟล์ **`config.js`**:

| ค่า | ความหมาย |
|-----|----------|
| `displayName` | ชื่อบน Dock / เมนูบาร์ / notification (เช่น `'Instagram'`) |
| `url` | หน้าเริ่มต้น (ดีฟอลต์ `tinder.com/app/recs`) |
| `location` | `null` = ใช้ GPS จริง / `{ latitude, longitude }` = ล็อกตำแหน่ง |
| `window` | ขนาดหน้าต่าง |
| `feed` | โหมด "เล่น Tinder เหมือนไถฟีด IG" (ดูหัวข้อถัดไป) |

## โหมดฟีด IG (เล่น Tinder เหมือนไถ Instagram)

เมื่อ `feed.enabled: true` การ์ด Tinder จะถูกจัดหน้าตาเป็น "โพสต์" ใน IG:
หัวโพสต์โชว์ชื่อ (+อายุ) ของคนในการ์ดจริง ๆ และมีแถวปุ่มแบบ IG ใต้รูป

| ท่าทาง / ปุ่ม | ทำอะไรใน Tinder |
|---|---|
| ดับเบิลแท็ปรูป | **Like** (หัวใจเด้งแบบ IG) |
| เลื่อนลงแรง ๆ (scroll) | **ข้ามคนนี้** (Nope) เหมือนเลื่อนผ่านโพสต์ |
| ❤️ (ใต้โพสต์) | Like |
| 💬 (ใต้โพสต์) | เปิดหน้าแชท/แมตช์ |
| ✈️ (ใต้โพสต์) | Super Like |
| 🔖 (ใต้โพสต์ ฝั่งขวา) | ข้ามคนนี้ (Nope) |
| 💬 (header ขวาบน) | เปิดหน้าแชท/แมตช์ |
| ❤️ (header ขวาบน) | กลับหน้า recs |
| 🏠 (แถบล่าง) | กลับหน้า recs |
| 🔍 (แถบล่าง) | **Tinder Explore** |
| ❤️ (แถบล่าง) | **Likes You** (ใครไลก์เรา) |
| ⭕ โปรไฟล์ (แถบล่าง) | โปรไฟล์เรา (แก้รูป/ตั้งค่า) |

ฟังก์ชันเดิมของ Tinder ยังครบ: หน้าแชทมีปุ่ม Back + ชื่อคู่สนทนา + ช่องพิมพ์
ตามปกติ (header ของหน้าแชทไม่ถูกซ่อน — ซ่อนเฉพาะแถบที่มีแบรนด์ Tinder)

นอกจากนี้ UI ของ Tinder ข้างในถูกลอกออกหมด: แถบบน (โลโก้ Tinder + Boost),
แถบล่าง (แท็บ Tinder/Explore/Likes You/ฯลฯ) และแถวปุ่ม Rewind/Nope/Like
ถูกซ่อน แล้วขยายรูปการ์ดเต็มพื้นที่ — เหลือแค่รูป + แถบ story ด้านบน +
ชื่อ/ระยะทางล่างรูป เหมือนโพสต์ IG จริง ๆ

กลไก: ปุ่ม/ท่าทางของเปลือกจะสั่ง `.click()` **ปุ่มจริงของ Tinder** ที่ซ่อนไว้
(เลย์เอาต์จอแคบของ Tinder ไม่รองรับคีย์ลัด) — 1 การกดของเรา = 1 แอ็กชัน
ไม่มีออโต้สไวป์

ตัวเลือกใน `config.js` → `feed`:

- `doubleTapLike` — เปิด/ปิดดับเบิลแท็ป
- `scrollToPass` — เปิด/ปิดเลื่อนเพื่อข้าม (มี threshold + cooldown กันพลาด)
- `hideTinderButtons` — ซ่อนแถวปุ่ม Rewind/Nope/Like เดิมของ Tinder
  (ดีฟอลต์ `true` — ปิดเป็น `false` ถ้าอยากเห็นปุ่มเดิม)

> หมายเหตุ: selector ที่ใช้ซ่อน UI / อ่านชื่อ ตรวจกับ DOM จริงของ Tinder แล้ว
> (`nav`, `main.mobile`, `.gamepad-button-wrapper`, `button.gamepad-button`)
> ถ้า Tinder อัปเดตหน้าเว็บ อาจต้องปรับใน `src/shell.js` / `src/preload.js`

ไอคอน: วาง `icon.png` (+ `icon.icns` สำหรับ build) ไว้ในโฟลเดอร์ `assets/`
(ดู `assets/README.txt`)

## เรื่อง location (สำคัญ)

Tinder ต้องใช้ตำแหน่ง ถ้า GPS จริงไม่ทำงานใน Electron ให้ตั้ง `location`
ใน `config.js` เป็นพิกัดที่ต้องการ เช่นกรุงเทพ:

```js
location: { latitude: 13.7563, longitude: 100.5018 },
```

(ถ้าอยากใช้ตำแหน่งจริงแบบ auto ต้องตั้ง env `GOOGLE_API_KEY` ที่เปิด
Geolocation API ไว้ตอนรัน — การ fix พิกัดเองง่ายและชัวร์กว่า)

## Build เป็น .app (อำพรางถาวร)

แก้ `productName` ใน `package.json` ให้ตรงกับ `displayName` ก่อน แล้ว:

```bash
npm run dist     # ได้ไฟล์ใน release/ : <productName>.dmg + .app
```

ลากแอปไป `/Applications` — Dock/Launchpad จะโชว์ชื่อ + ไอคอนที่อำพรางไว้

## หมายเหตุความปลอดภัย

- ตอนตั้ง `location` โค้ดจะปิด `contextIsolation` เพื่อ spoof พิกัด — รับได้
  เพราะโหลดแค่ `tinder.com` ที่เชื่อถือได้ ถ้า `location: null` จะเปิด
  `contextIsolation` ไว้ตามปกติ
- session แยกใน partition ของแอปนี้ ไม่ปนกับ Chrome/Safari ปกติ
