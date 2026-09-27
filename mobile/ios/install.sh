#!/bin/bash
# ติดตั้งแอปลง iPhone ที่เสียบสาย/อยู่วง WiFi เดียวกัน
# build แบบ Release: ปิด log + Web Inspector (โค้ดที่ครอบ #if DEBUG ไม่ถูกคอมไพล์)
# ใช้หลังจากเปิด Developer Mode + เพิ่ม Apple ID ใน Xcode แล้ว
set -e
cd "$(dirname "$0")"

DEVICE_ID="${DEVICE_ID:-00008110-000E78160201401E}"   # iPhone's Wave
TEAM_ID="${TEAM_ID:-QRPJ6S6PC6}"                        # Personal Team (free provisioning)
DD="build/DD"

echo "▶︎ building + signing…"
xcodebuild -project Instagram.xcodeproj -scheme Instagram \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  -derivedDataPath "$DD" \
  build

APP="$DD/Build/Products/Release-iphoneos/Instagram.app"
echo "▶︎ installing $APP …"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP"

echo "✅ ติดตั้งเสร็จ — เปิดแอป 'Prism' บนเครื่องได้เลย"
echo "   (ครั้งแรกอาจต้องไป Settings → General → VPN & Device Management → เชื่อถือ developer)"
