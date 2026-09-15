วางไอคอนอำพรางไว้ที่นี่ / Put your disguise icon here:

  icon.png   — ใช้ตอนรันโหมด dev (แนะนำ 512x512 หรือ 1024x1024)
  icon.icns  — ใช้ตอน build เป็น .app (macOS)

เคล็ดลับ: อยากให้เหมือน Instagram ก็เอาไอคอน Instagram (หรือ Photos/Gallery)
มาตั้งชื่อตามนี้ แล้ววางทับไฟล์ตัวอย่าง

วิธีแปลง PNG -> ICNS บน macOS:
  1) mkdir icon.iconset
  2) sips -z 512 512 icon.png --out icon.iconset/icon_512x512.png
     (ทำหลายขนาด: 16,32,128,256,512 และ @2x ตามต้องการ)
  3) iconutil -c icns icon.iconset -o icon.icns
