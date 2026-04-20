#!/usr/bin/env bash
# Скачивает и распаковывает плагин godotx_revenue_cat в addons/.
# Бинарники (iOS xcframeworks) не коммитятся — ~850MB.
# Использование: ./scripts/install_revenuecat.sh

set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

PLUGIN_VERSION="${REVENUECAT_PLUGIN_VERSION:-0.5.0}"
PLUGIN_URL="https://github.com/RevenueCat/purchases-godot/releases/download/${PLUGIN_VERSION}/godotx_revenue_cat-${PLUGIN_VERSION}.zip"
ADDONS_DIR="addons"
PLUGIN_DIR="${ADDONS_DIR}/godotx_revenue_cat"

mkdir -p "$ADDONS_DIR"
if [ -d "$PLUGIN_DIR" ]; then
    echo "Плагин уже установлен в $PLUGIN_DIR (версия не проверяется)."
    exit 0
fi

TMP="$(mktemp -d)"
echo "Скачиваю $PLUGIN_URL…"
curl -L -o "$TMP/plugin.zip" "$PLUGIN_URL"
unzip -q "$TMP/plugin.zip" -d "$TMP/extracted"

# Внутри архива ожидается папка addons/godotx_revenue_cat/
if [ -d "$TMP/extracted/addons/godotx_revenue_cat" ]; then
    mv "$TMP/extracted/addons/godotx_revenue_cat" "$PLUGIN_DIR"
elif [ -d "$TMP/extracted/godotx_revenue_cat" ]; then
    mv "$TMP/extracted/godotx_revenue_cat" "$PLUGIN_DIR"
else
    echo "ошибка: структура архива не распознана" >&2
    ls -la "$TMP/extracted"
    exit 1
fi

rm -rf "$TMP"
echo "✓ Плагин RevenueCat установлен в $PLUGIN_DIR"
echo "  Включите его: Project → Project Settings → Plugins → godotx_revenue_cat → Enable"
