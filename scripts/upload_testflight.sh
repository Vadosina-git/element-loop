#!/usr/bin/env bash
# Загружает подписанный .ipa в TestFlight через ASC API key.
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

[ -f .appstore.env ] || { echo "ошибка: .appstore.env отсутствует"; exit 1; }
set -a; source .appstore.env; set +a
APP_STORE_API_KEY_PATH="$(eval echo "$APP_STORE_API_KEY_PATH")"
: "${APP_STORE_ISSUER_ID:?}"
: "${APP_STORE_API_KEY_ID:?}"
[ -f "$APP_STORE_API_KEY_PATH" ] || { echo "ошибка: $APP_STORE_API_KEY_PATH отсутствует"; exit 1; }

IPA="${1:-builds/ios/export/BoxMaster.ipa}"
[ -f "$IPA" ] || { echo "ошибка: $IPA отсутствует. Сначала сделайте Archive в Xcode."; exit 1; }

xcrun altool --upload-app --file "$IPA" --type ios \
    --apiKey "$APP_STORE_API_KEY_ID" --apiIssuer "$APP_STORE_ISSUER_ID"
echo "✓ Загружено. Проверяйте https://appstoreconnect.apple.com → TestFlight."
