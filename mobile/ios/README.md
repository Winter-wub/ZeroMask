# Prism (iOS) — Tinder wrapper แบบอำพราง

แอป iOS เนทีฟ (SwiftUI + WKWebView) ห่อ Tinder web ไว้ ชื่อ/ไอคอนบนเครื่องเป็น
**"Prism"** (ตั้งใน `project.yml` → `CFBundleDisplayName`)

- โหมดอำพรางเลือกได้ใน Settings: 💎 Liquid Glass / 🔥 Tinder / 🤖 ChatGPT 4o
- ปุ่มสลับไปเปิด instagram.com จริง (session แยก) พร้อมเลขแชทค้างบนปุ่ม
- แจ้งเตือนแบบพราง (ข้อความสไตล์ AI Agent หรือ Instagram) + badge บนไอคอน
  ตรวจแชทใหม่ผ่าน background refresh ด้วย token ที่ดักจากหน้าเว็บ (เก็บใน Keychain)
- สลับแอป / App Switcher → หน้าจอบัง "Privacy Shield" แบบแอปธนาคาร

## PIN 2 ชุด (หลัก + สำรอง)

ตั้งใน **การตั้งค่า** (ปุ่ม `···` มุมขวาบน):

| ชุด | ใส่ที่หน้าล็อกแล้วได้อะไร |
|-----|---------------------------|
| **PIN หลัก** (หัวข้อ "ความปลอดภัย") | เข้าแอปตามปกติ (หน้าตาตามโหมดอำพรางที่เลือก) |
| **PIN สำรอง** (หัวข้อ "PIN สำรอง") | เปิดเว็บ PickleWatch **ตัวจริง** เต็มจอ ไม่เห็นแอปข้างในเลย |

- PIN สำรองตั้งได้ต่อเมื่อเปิด PIN หลักไว้แล้ว และห้ามตั้งซ้ำกับ PIN หลัก
- **ต้องใส่ลิงก์ถ่ายทอดสดเอง** ในหน้าเดียวกัน (ดีฟอลต์ว่าง) — พิมพ์แค่โดเมนได้ แอปเติม `https://` ให้
  ถ้ายังว่าง/ไม่ใช่ลิงก์เว็บ Settings จะขึ้นคำเตือนสีส้ม เพราะใส่ PIN สำรองแล้วจะได้จอขาว
- ออกจากโหมด PIN สำรอง: **แตะมุมซ้ายบน 5 ครั้งติด ๆ** → กลับหน้าล็อกเพื่อใส่ PIN หลัก
  (สลับแอปออกไปก็ออกจากโหมดนี้เหมือนกัน)
- webview ของโหมดนี้ใช้ session แบบไม่จำ (non-persistent) แยกจาก Tinder/Instagram

### กันเดา PIN

- ใส่ผิดติดกันครั้งที่ 5 ต้องรอ 30 วิ → 1 นาที → 5 นาที → 15 นาที (ครั้งต่อ ๆ ไป)
- ตัวนับเก็บใน Keychain — ปิดแล้วเปิดแอปใหม่ก็ไม่รีเซ็ต ใส่ PIN ถูก (หลักหรือสำรอง) หรือ Face ID ผ่านถึงจะรีเซ็ต

### Face ID กับ PIN สำรอง

ถ้าตั้ง PIN สำรองไว้ แอปจะ **ไม่เด้ง Face ID เองตอนเปิด** (ไม่งั้นใครยื่นเครื่องมาที่หน้าเรา
ก็เข้าแอปจริงได้ทันที ข้ามหน้า PIN สำรอง) — ยังกดปุ่ม Face ID ที่แป้นตัวเลขเองได้

## ข้อมูลที่เก็บในเครื่อง

| ข้อมูล | เก็บที่ | หมายเหตุ |
|--------|--------|----------|
| PIN หลัก/สำรอง | Keychain (`WhenUnlockedThisDeviceOnly`) | เก็บเป็น PBKDF2-SHA256 (600k รอบ) + salt ไม่เก็บ PIN ตรง ๆ — PIN ที่ตั้งไว้แบบเก่า (SHA-256) อัปเกรดให้เองตอนปลดล็อกครั้งแรก |
| ตัวนับใส่ PIN ผิด | Keychain | ปิด-เปิดแอปใหม่ไม่รีเซ็ต |
| Tinder token / IG session | Keychain (`AfterFirstUnlockThisDeviceOnly`) | ให้ background fetch อ่านได้ตอนจอล็อก ไม่ติดไปกับ backup |
| login/cookie ของเว็บ | `WKWebsiteDataStore.default()` | โหมด PIN สำรองใช้ store แบบ non-persistent แยก |
| การตั้งค่า + ยอดแชทค้าง | UserDefaults | |

"ออกจากระบบ / ล้างข้อมูล" ใน Settings จะล้าง cookie/session และ token ทั้งหมด

## โครงสร้างโค้ด (`Sources/`)

| ไฟล์ | หน้าที่ |
|------|--------|
| `InstagramApp.swift` | entry point, ลงทะเบียน background task |
| `RootView.swift` | ครอบทั้งแอป: หน้าล็อก, โหมด PIN สำรอง, Privacy Shield |
| `ContentView.swift` | หน้าจอหลักตามโหมดอำพราง + แชทเต็มจอ + สลับไป IG |
| `TinderWebView.swift` | `MaskModel`: webview Tinder/IG, รับ event จาก JS (รับเฉพาะ main frame ของโดเมนจริง) |
| `MaskScripts.swift` | JS/CSS ที่ฉีดเข้าเว็บ (ลอก UI, ดักท่าทาง, ดัก token/ยอดแชท) |
| `LockView.swift` / `PinStore.swift` | แป้น PIN, Face ID, กันเดา PIN |
| `PickleLiveView.swift` | โหมด PIN สำรอง (เว็บ PickleWatch เต็มจอ) |
| `NotificationManager.swift` | badge + แจ้งเตือนแบบพราง |
| `BackgroundTaskManager.swift` | background refresh เช็กแชทใหม่ Tinder/IG |
| `KeychainTokenStore.swift` | เก็บ token/session ใน Keychain |
| `SettingsView.swift` / `AppSettings.swift` | หน้าตั้งค่า + ค่าที่จำไว้, `dlog()` (log เฉพาะ debug) |

## ติดตั้งลงเครื่อง

```bash
./install.sh
```

สคริปต์จะ build แบบ **Release** (ตัด log + Safari Web Inspector ที่ครอบ `#if DEBUG` ออก),
เซ็นด้วย Personal Team แล้วติดตั้งลง iPhone ผ่าน `devicectl`
ค่าที่ใช้อยู่ในสคริปต์ override ได้ด้วย env:

| ตัวแปร | ค่าเริ่มต้น | หาได้จาก |
|--------|-------------|----------|
| `DEVICE_ID` | `00008110-000E78160201401E` (iPhone's Wave) | `xcrun devicectl list devices` |
| `TEAM_ID` | `QRPJ6S6PC6` (Personal Team) | Xcode → Settings → Accounts |

```bash
DEVICE_ID=<udid> TEAM_ID=<team> ./install.sh   # ลงเครื่องอื่น / ทีมอื่น
```

### ตั้งค่าครั้งแรก (ทำครั้งเดียว)

1. **เปิด Developer Mode บน iPhone:** Settings → Privacy & Security → Developer Mode → เปิด → รีสตาร์ทเครื่อง
2. **เพิ่ม Apple ID ใน Xcode:** Xcode → Settings (⌘,) → Accounts → ปุ่ม + → Apple ID
3. **เสียบสาย iPhone เข้า Mac** (ครั้งแรก — ต่อไปใช้ WiFi วงเดียวกันได้) แล้วรัน `./install.sh`
4. **เชื่อถือ developer** (ครั้งแรกเท่านั้น): บนเครื่อง Settings → General → VPN & Device Management → แตะชื่อ dev → Trust

> ถ้าแก้ `project.yml` ต้องรัน `xcodegen generate` ใหม่ก่อน build

## หมายเหตุ

- ใช้ free provisioning ได้ (ไม่ต้องจ่าย $99) แต่แอปจะหมดอายุทุก **7 วัน**
  ต้องรัน `./install.sh` ใหม่เพื่อต่ออายุ (ข้อมูล/ล็อกอินในแอปยังอยู่) — ถ้าจ่าย Apple Developer จะได้ 1 ปี
- session/login ของ Tinder เก็บในเครื่อง (WKWebsiteDataStore) ล็อกอินครั้งเดียวจำไว้
- location ใช้ GPS จริงของ iPhone (Tinder ขอ permission เอง)
