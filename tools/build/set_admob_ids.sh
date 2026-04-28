#!/usr/bin/env bash
# set_admob_ids.sh — Environment variable → admob_ids.cfg oluşturucu
#
# CI pipeline'da gerçek AdMob ID'lerini config dosyasına yazar.
# Bu dosya gitignore'da; ASLA commit edilmez.
#
# Kullanım:
#   ADMOB_APP_ID="ca-app-pub-XXXX~YYYY" \
#   ADMOB_OFFLINE_BOOST="ca-app-pub-XXXX/YYYY" \
#   ADMOB_DAILY_BONUS="ca-app-pub-XXXX/ZZZZ" \
#   ADMOB_INSTANT_BAKE="ca-app-pub-XXXX/AAAA" \
#   ADMOB_VIP_EXTEND="ca-app-pub-XXXX/BBBB" \
#   ADMOB_TASK_DOUBLE="ca-app-pub-XXXX/CCCC" \
#   ./tools/build/set_admob_ids.sh
#
# Çıktı: config/admob_ids.cfg (GDScript ConfigFile formatı)

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUTPUT="$PROJECT_ROOT/config/admob_ids.cfg"

# Zorunlu değişken kontrolü
REQUIRED_VARS=(
    ADMOB_APP_ID
    ADMOB_OFFLINE_BOOST
    ADMOB_DAILY_BONUS
    ADMOB_INSTANT_BAKE
    ADMOB_VIP_EXTEND
    ADMOB_TASK_DOUBLE
)

MISSING=()
for VAR in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!VAR:-}" ]]; then
        MISSING+=("$VAR")
    fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "HATA: Şu ortam değişkenleri eksik:" >&2
    for M in "${MISSING[@]}"; do
        echo "  - $M" >&2
    done
    exit 1
fi

mkdir -p "$(dirname "$OUTPUT")"

cat > "$OUTPUT" <<CFG
; admob_ids.cfg — OTOMATIK OLUŞTURULDU — GIT'E EKLEMEYİN
; set_admob_ids.sh tarafından oluşturuldu.

[admob]
app_id="${ADMOB_APP_ID}"

[placements]
offline_boost="${ADMOB_OFFLINE_BOOST}"
daily_bonus="${ADMOB_DAILY_BONUS}"
instant_bake="${ADMOB_INSTANT_BAKE}"
vip_extend="${ADMOB_VIP_EXTEND}"
task_double="${ADMOB_TASK_DOUBLE}"
CFG

echo "admob_ids.cfg oluşturuldu: $OUTPUT"
echo "  App ID: ${ADMOB_APP_ID:0:20}... (gizlendi)"
