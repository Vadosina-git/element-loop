#!/usr/bin/env bash
# Собирает подписанный Android release APK для Box Master.
# Креды берутся из .keystore.env (gitignored). Скрипт временно подставляет
# их в export_presets.cfg на время сборки и восстанавливает файл после.
# Использование: ./scripts/build_android_release.sh [путь_к_APK]

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

if [ ! -f .keystore.env ]; then
    echo "ошибка: .keystore.env не найден в корне проекта" >&2
    exit 1
fi

# shellcheck disable=SC1091
source .keystore.env
: "${ANDROID_KEYSTORE_PATH:?ANDROID_KEYSTORE_PATH обязателен}"
: "${ANDROID_KEYSTORE_USER:?ANDROID_KEYSTORE_USER обязателен}"
: "${ANDROID_KEYSTORE_PASSWORD:?ANDROID_KEYSTORE_PASSWORD обязателен}"

OUTPUT="${1:-builds/android/boxmaster_release.apk}"
mkdir -p "$(dirname "$OUTPUT")"

cp export_presets.cfg export_presets.cfg.bak
trap 'mv -f export_presets.cfg.bak export_presets.cfg' EXIT

sed -i '' \
    -e "s|keystore/release=\"\"|keystore/release=\"${ANDROID_KEYSTORE_PATH}\"|" \
    -e "s|keystore/release_user=\"\"|keystore/release_user=\"${ANDROID_KEYSTORE_USER}\"|" \
    -e "s|keystore/release_password=\"\"|keystore/release_password=\"${ANDROID_KEYSTORE_PASSWORD}\"|" \
    export_presets.cfg

GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
"$GODOT" --headless --path . --export-release "Android" "$OUTPUT"

echo "✓ Release APK собран: $OUTPUT"
