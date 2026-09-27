# mask-of-sex

ห่อ **Tinder web** ไว้ในแอปที่อำพรางชื่อ + ไอคอนเป็นแอปอื่น

> ใช้สำหรับเครื่องตัวเองเท่านั้น เป็นแค่การห่อเว็บ ไม่มีบอท/ไม่ออโต้สไวป์
> (การออโต้สไวป์ผิด ToS ของ Tinder)

## iOS — "Prism"

แอป SwiftUI + WKWebView อยู่ใน [`mobile/ios`](mobile/ios/README.md)
(PIN หลัก/สำรอง, กันเดา PIN, Privacy Shield, แจ้งเตือนแบบพราง)

ติดตั้งลง iPhone (เสียบสายหรืออยู่ WiFi วงเดียวกัน):

```bash
./mobile/ios/install.sh
```

สคริปต์ build แบบ **Release** + เซ็นด้วย Personal Team แล้วติดตั้งลงเครื่องให้เลย
ใช้ free provisioning → แอปหมดอายุทุก **7 วัน** ต้องรันสคริปต์ใหม่เพื่อต่ออายุ
(ขั้นตอนตั้งค่าครั้งแรก + เปลี่ยนเครื่อง/ทีม ดู [`mobile/ios/README.md`](mobile/ios/README.md))
