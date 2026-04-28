#!/usr/bin/env bash
# run_tests.sh — GUT test koşusu (CI + yerel geliştirme)
#
# Kullanım:
#   ./tools/ci/run_tests.sh                    # tüm testler
#   ./tools/ci/run_tests.sh tests/unit/test_economy_system.gd  # tek dosya
#
# Çıktı: konsol + JUnit XML (test-results/gut_results.xml)
# Çıkış kodu: 0 → başarılı, 1 → failure var
#
# Gereksinimler: GODOT_BIN ortam değişkeni (varsayılan: godot)

set -euo pipefail

GODOT="${GODOT_BIN:-godot}"
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
RESULTS_DIR="${PROJECT_DIR}/test-results"
GUT_CLI="${PROJECT_DIR}/addons/gut/gut_cli.gd"
OUTPUT_FILE="${RESULTS_DIR}/gut_results.xml"

mkdir -p "${RESULTS_DIR}"

echo "=== Ekmek Ustası — GUT Test Koşusu ==="
echo "Proje: ${PROJECT_DIR}"
echo "Godot: ${GODOT}"
echo ""

# Tek dosya argümanı verilmişse yalnızca onu koş
if [[ $# -ge 1 && -f "$1" ]]; then
  TEST_ARG="-gtest=$1"
else
  TEST_ARG="-gdir=tests/unit"
fi

"${GODOT}" \
  --headless \
  --path "${PROJECT_DIR}" \
  -s "${GUT_CLI}" \
  ${TEST_ARG} \
  -gconfig=.gut_config.json \
  -gjunit_xml_file="${OUTPUT_FILE}" \
  -gexit \
  2>&1

EXIT_CODE=$?

echo ""
if [[ $EXIT_CODE -eq 0 ]]; then
  echo "✓ Tüm testler geçti"
else
  echo "✗ Başarısız testler var (çıkış kodu: ${EXIT_CODE})"
fi

echo "Rapor: ${OUTPUT_FILE}"
exit ${EXIT_CODE}
