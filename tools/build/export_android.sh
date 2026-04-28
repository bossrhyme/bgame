#!/usr/bin/env bash
# export_android.sh — Godot 4.6 Android .aab export
#
# Kullanım:
#   ./tools/build/export_android.sh [release|debug]
#
# Gereksinimler:
#   - GODOT_BIN: Godot 4.6 binary (varsayılan: godot)
#   - KEYSTORE_PATH: Release keystore dosya yolu (release build için zorunlu)
#   - KEYSTORE_PASS: Keystore şifresi
#   - KEYSTORE_ALIAS: Key alias
#   - KEYSTORE_ALIAS_PASS: Key alias şifresi
#   - ADMOB_CONFIG: admob_ids.cfg kaynak yolu (opsiyonel)
#
# CI örneği:
#   GODOT_BIN=/opt/godot-4.6/godot \
#   KEYSTORE_PATH=/secrets/release.keystore \
#   KEYSTORE_PASS=${{ secrets.KEYSTORE_PASS }} \
#   KEYSTORE_ALIAS=upload \
#   KEYSTORE_ALIAS_PASS=${{ secrets.KEY_PASS }} \
#   ./tools/build/export_android.sh release

set -euo pipefail

BUILD_TYPE="${1:-debug}"
GODOT="${GODOT_BIN:-godot}"
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/build/android"
EXPORT_NAME="breadmaster"

# ── Doğrulama ────────────────────────────────────────────────────────────────

if ! command -v "$GODOT" &>/dev/null; then
    echo "HATA: Godot binary bulunamadı: $GODOT" >&2
    echo "  GODOT_BIN ortam değişkenini ayarlayın." >&2
    exit 1
fi

if [[ "$BUILD_TYPE" == "release" ]]; then
    if [[ -z "${KEYSTORE_PATH:-}" ]]; then
        echo "HATA: Release build için KEYSTORE_PATH gerekli." >&2
        exit 1
    fi
    if [[ ! -f "$KEYSTORE_PATH" ]]; then
        echo "HATA: Keystore dosyası bulunamadı: $KEYSTORE_PATH" >&2
        exit 1
    fi
fi

# ── AdMob Config Enjeksiyonu ─────────────────────────────────────────────────

if [[ -n "${ADMOB_CONFIG:-}" && -f "$ADMOB_CONFIG" ]]; then
    echo "AdMob config enjekte ediliyor: $ADMOB_CONFIG"
    cp "$ADMOB_CONFIG" "$PROJECT_ROOT/config/admob_ids.cfg"
else
    echo "Uyarı: ADMOB_CONFIG ayarlı değil — test ID'leri kullanılacak."
fi

# ── Export ───────────────────────────────────────────────────────────────────

mkdir -p "$OUTPUT_DIR"

EXPORT_PRESET="Android"
if [[ "$BUILD_TYPE" == "release" ]]; then
    EXPORT_PRESET="Android Release"
fi

OUTPUT_FILE="$OUTPUT_DIR/${EXPORT_NAME}.aab"

echo "Godot Android export başlıyor..."
echo "  Preset: $EXPORT_PRESET"
echo "  Çıktı : $OUTPUT_FILE"
echo "  Tip   : $BUILD_TYPE"

"$GODOT" \
    --headless \
    --path "$PROJECT_ROOT" \
    --export-release "$EXPORT_PRESET" "$OUTPUT_FILE"

# ── Sonuç ────────────────────────────────────────────────────────────────────

if [[ -f "$OUTPUT_FILE" ]]; then
    SIZE=$(du -sh "$OUTPUT_FILE" | cut -f1)
    echo "Export tamamlandı: $OUTPUT_FILE ($SIZE)"
else
    echo "HATA: Export dosyası oluşturulamadı." >&2
    exit 1
fi

# ── Temizlik ─────────────────────────────────────────────────────────────────
# Enjekte edilen AdMob config'i sil (gerçek ID'ler çalışma dizininde kalmasın)
if [[ -f "$PROJECT_ROOT/config/admob_ids.cfg" ]]; then
    rm -f "$PROJECT_ROOT/config/admob_ids.cfg"
    echo "AdMob config temizlendi."
fi

echo "Bitti."
