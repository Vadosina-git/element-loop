#!/usr/bin/env bash
# Пост-экспорт патч для iOS. Godot перезаписывает Info.plist,
# PrivacyInfo.xcprivacy и project.pbxproj при каждом экспорте — этот скрипт
# заново применяет наши App Store-ready модификации. Запускать ПОСЛЕ каждого
# iOS-экспорта.

set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

INFO_PLIST="builds/ios/BoxMaster/BoxMaster-Info.plist"
PRIVACY="builds/ios/PrivacyInfo.xcprivacy"
PBXPROJ="builds/ios/BoxMaster.xcodeproj/project.pbxproj"

[ -f "$INFO_PLIST" ] || { echo "ошибка: $INFO_PLIST не найден. Сначала запустите iOS-экспорт." >&2; exit 1; }
[ -f "$PBXPROJ" ]  || { echo "ошибка: $PBXPROJ не найден." >&2; exit 1; }

# 1. Info.plist — ландшафтная ориентация + убрать лишние usage descriptions
python3 - <<PY
import plistlib
from pathlib import Path
path = Path("$INFO_PLIST")
data = plistlib.loads(path.read_bytes())
data["UISupportedInterfaceOrientations"] = [
    "UIInterfaceOrientationLandscapeLeft",
    "UIInterfaceOrientationLandscapeRight",
]
data["UISupportedInterfaceOrientations~ipad"] = data["UISupportedInterfaceOrientations"]
for key in ("NSCameraUsageDescription", "NSPhotoLibraryUsageDescription",
            "NSMicrophoneUsageDescription"):
    data.pop(key, None)
data["UIRequiredDeviceCapabilities"] = ["arm64"]
data["ITSAppUsesNonExemptEncryption"] = False
path.write_bytes(plistlib.dumps(data))
print(f"✓ Пропатчен {path}")
PY

# 2. PrivacyInfo.xcprivacy — полная замена (App Store-ready)
cat > "$PRIVACY" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>NSPrivacyTracking</key><false/>
  <key>NSPrivacyTrackingDomains</key><array/>
  <key>NSPrivacyCollectedDataTypes</key><array/>
  <key>NSPrivacyAccessedAPITypes</key>
  <array>
    <dict>
      <key>NSPrivacyAccessedAPIType</key><string>NSPrivacyAccessedAPICategoryUserDefaults</string>
      <key>NSPrivacyAccessedAPITypeReasons</key><array><string>CA92.1</string></array>
    </dict>
    <dict>
      <key>NSPrivacyAccessedAPIType</key><string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
      <key>NSPrivacyAccessedAPITypeReasons</key><array><string>DDA9.1</string><string>C617.1</string></array>
    </dict>
    <dict>
      <key>NSPrivacyAccessedAPIType</key><string>NSPrivacyAccessedAPICategorySystemBootTime</string>
      <key>NSPrivacyAccessedAPITypeReasons</key><array><string>35F9.1</string></array>
    </dict>
    <dict>
      <key>NSPrivacyAccessedAPIType</key><string>NSPrivacyAccessedAPICategoryDiskSpace</string>
      <key>NSPrivacyAccessedAPITypeReasons</key><array><string>E174.1</string><string>85F4.1</string></array>
    </dict>
  </array>
</dict>
</plist>
EOF
echo "✓ Пропатчен $PRIVACY"

# 3. pbxproj: только iPhone + нормализация signing identity
if grep -q 'TARGETED_DEVICE_FAMILY = "1,2"' "$PBXPROJ"; then
    sed -i '' 's/TARGETED_DEVICE_FAMILY = "1,2"/TARGETED_DEVICE_FAMILY = "1"/g' "$PBXPROJ"
    echo "✓ iPhone-only"
fi
if grep -q 'CODE_SIGN_IDENTITY = "Apple Distribution"' "$PBXPROJ"; then
    sed -i '' 's/CODE_SIGN_IDENTITY = "Apple Distribution"/CODE_SIGN_IDENTITY = "Apple Development"/g' "$PBXPROJ"
    echo "✓ Signing нормализован для Automatic"
fi
echo "Готово. Откройте builds/ios/BoxMaster.xcodeproj в Xcode."
