#!/bin/bash
# 只重新测试上一次报告中异常的 4 个组合
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ORIG_XRAY_DIR="${HOME}/bin/xray-core"
ORIG_SINGBOX_DIR="${HOME}/bin/sing-box"
REPORT_DIR="${BASE_DIR}/Build/tests/reports"

echo "=== Creating temporary binary dir with only needed versions ==="

# Backup full dirs, create temp ones with only needed versions
for core in xray-core sing-box; do
  if [ -L "${HOME}/bin/$core" ]; then
    echo "ERROR: ${HOME}/bin/$core is already a symlink, restore first"
    exit 1
  fi
done

# Move originals aside
mv "$ORIG_XRAY_DIR" "${ORIG_XRAY_DIR}.bak"
mv "$ORIG_SINGBOX_DIR" "${ORIG_SINGBOX_DIR}.bak"

# Create minimal dirs with only the versions we need
mkdir -p "$ORIG_XRAY_DIR"
mkdir -p "$ORIG_SINGBOX_DIR"

# Copy needed xray versions
for v in v25.9.5 v26.2.6 v26.3.27; do
  cp -a "${ORIG_XRAY_DIR}.bak/$v" "$ORIG_XRAY_DIR/$v"
done

# Copy needed sing-box version
cp -a "${ORIG_SINGBOX_DIR}.bak/v1.13.2" "$ORIG_SINGBOX_DIR/v1.13.2"

cleanup() {
  echo ""
  echo "=== Restoring original binary directories ==="
  rm -rf "$ORIG_XRAY_DIR" "$ORIG_SINGBOX_DIR"
  mv "${ORIG_XRAY_DIR}.bak" "$ORIG_XRAY_DIR"
  mv "${ORIG_SINGBOX_DIR}.bak" "$ORIG_SINGBOX_DIR"
  echo "Restored."
}
trap cleanup EXIT

echo ""
echo "=== Running targeted re-test ==="
cd "$BASE_DIR"
xcodebuild test \
  -project V2rayU.xcodeproj \
  -scheme V2rayU \
  -destination 'platform=macOS' \
  -only-testing:V2rayUTests/CompatibilityTestRunner \
  2>&1 | tee "${REPORT_DIR}/retest-last-run.log"

echo ""
echo "=== Result ==="
LATEST_REPORT=$(ls -t "${REPORT_DIR}"/compatibility-report-*.json 2>/dev/null | head -1)
if [ -n "$LATEST_REPORT" ]; then
  python3 -c "
import json
with open('$LATEST_REPORT') as f:
    r = json.load(f)
print('Total:', r['summary']['totalCombinations'])
print('Passed:', r['summary']['passed'])
print('Failed:', r['summary']['failed'])
print('Skipped:', r['summary']['skipped'])
print('Mismatches:', r['summary']['ruleMismatchCount'])
print()
for m in r.get('ruleMismatches', []):
    print(f'  MISMATCH: [{m[\"coreType\"]} {m[\"coreVersion\"]}] {m[\"profileRemark\"]}: pred={m[\"rulePredicted\"]}, actual={m[\"actualStatus\"]}')
if r['summary']['ruleMismatchCount'] == 0:
    print()
    print('All combinations handled correctly (no mismatches)!')
"
fi
