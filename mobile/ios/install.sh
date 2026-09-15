#!/bin/bash
# ติดตั้งแอปลง iPhone ที่เสียบสาย/อยู่วง WiFi เดียวกัน
# ใช้หลังจากเปิด Developer Mode + เพิ่ม Apple ID ใน Xcode แล้ว
set -e
cd "$(dirname "$0")"

DEVICE_ID="00008110-000E78160201401E"   # iPhone's Wave
DD="build/DD"

echo "▶︎ building + signing…"
xcodebuild -project Instagram.xcodeproj -scheme Instagram \
  -destination "platform=iOS,id=$DEVICE_ID" \
  -allowProvisioningUpdates \
  -derivedDataPath "$DD" \
  build

APP="$DD/Build/Products/Debug-iphoneos/Instagram.app"
echo "▶︎ installing $APP …"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP"

echo "✅ ติดตั้งเสร็จ — เปิดแอป 'Instagram' บนเครื่องได้เลย"
echo "   (ครั้งแรกอาจต้องไป Settings → General → VPN & Device Management → เชื่อถือ developer)"
