#!/bin/bash
#
# run-compatibility-test.sh — 运行跨版本兼容性测试
#
# 用法:
#   ./Build/tests/run-compatibility-test.sh            # 完整运行
#   ./Build/tests/run-compatibility-test.sh --download  # 先下载核心，再测试
#
# 流程:
#   1. (可选) 下载所有核心版本
#   2. xcodebuild test 运行 CompatibilityTestRunner
#   3. 报告输出到 Build/tests/reports/compatibility-report-{timestamp}.json
#
# 环境变量:
#   V2RAYU_TEST_BIN_DIR    - 核心二进制目录 (默认: Build/tests/bin)
#   V2RAYU_TEST_REPORT_DIR - 报告输出目录 (默认: Build/tests/reports)
#   V2RAYU_SKIP_DOWNLOAD   - 设为 1 可跳过下载步骤
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_BIN_DIR="${V2RAYU_TEST_BIN_DIR:-${BASE_DIR}/Build/tests/bin}"
TEST_REPORT_DIR="${V2RAYU_TEST_REPORT_DIR:-${BASE_DIR}/Build/tests/reports}"
DOWNLOAD_SCRIPT="${BASE_DIR}/Build/tests/download-cores.py"
DOWNLOAD_SCRIPT_BASH="${BASE_DIR}/Build/tests/download-cores.sh"

SCRIPT_NAME="$(basename "$0")"

# ---------- 颜色输出 ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ---------- 参数解析 ----------
DO_DOWNLOAD=false
if [ $# -gt 0 ]; then
    case "$1" in
        --download|-d) DO_DOWNLOAD=true ;;
        --help|-h)
            echo "Usage: $SCRIPT_NAME [--download]"
            echo ""
            echo "  --download, -d  Download core binaries before running tests"
            exit 0
            ;;
        *) error "Unknown option: $1"; exit 1 ;;
    esac
fi

# ---------- 1. 检查/下载核心版本 ----------
if [ "$DO_DOWNLOAD" = true ]; then
    if [ -f "$DOWNLOAD_SCRIPT" ]; then
        info "Downloading core binaries (Python)..."
        python3 "$DOWNLOAD_SCRIPT"
    elif [ -f "$DOWNLOAD_SCRIPT_BASH" ]; then
        info "Downloading core binaries (bash)..."
        bash "$DOWNLOAD_SCRIPT_BASH"
    else
        warn "Download script not found"
    fi
fi

# ---------- 2. 检查核心二进制是否存在 ----------
XRAY_COUNT=$(find "${TEST_BIN_DIR}/xray-core" -type f 2>/dev/null | wc -l | tr -d ' ')
SINGBOX_COUNT=$(find "${TEST_BIN_DIR}/sing-box" -type f 2>/dev/null | wc -l | tr -d ' ')

if [ "$XRAY_COUNT" -eq 0 ] && [ "$SINGBOX_COUNT" -eq 0 ]; then
    error "No core binaries found in ${TEST_BIN_DIR}"
    error "Run '$DOWNLOAD_SCRIPT' first or use '--download' flag"
    exit 1
fi

info "Found $XRAY_COUNT xray-core and $SINGBOX_COUNT sing-box binaries"

# ---------- 3. 准备报告目录 ----------
mkdir -p "$TEST_REPORT_DIR"

# ---------- 4. 运行测试 ----------
info "Running compatibility tests (this may take a while)..."
info "Test binaries: $TEST_BIN_DIR"
info "Report output: $TEST_REPORT_DIR"

export V2RAYU_TEST_BIN_DIR="$TEST_BIN_DIR"
export V2RAYU_TEST_REPORT_DIR="$TEST_REPORT_DIR"
export V2RAYU_MAX_PROFILES="${V2RAYU_MAX_PROFILES:-4}"
export V2RAYU_SAMPLE_VERSIONS="${V2RAYU_SAMPLE_VERSIONS:-3}"

cd "$BASE_DIR"

set +e
xcodebuild test \
    -project V2rayU.xcodeproj \
    -scheme V2rayU \
    -destination 'platform=macOS' \
    -only-testing:V2rayUTests/CompatibilityTestRunner \
    -resultBundlePath "${TEST_REPORT_DIR}/last-run.xcresult" \
    2>&1 | tee "${TEST_REPORT_DIR}/last-run.log"

EXIT_CODE=$?
set -e

# ---------- 5. 查找最新报告 ----------
LATEST_REPORT=$(ls -t "${TEST_REPORT_DIR}"/compatibility-report-*.json 2>/dev/null | head -1)

if [ -n "$LATEST_REPORT" ]; then
    PASSED=$(jq -r '.summary.passed // 0' "$LATEST_REPORT")
    FAILED=$(jq -r '.summary.failed // 0' "$LATEST_REPORT")
    SKIPPED=$(jq -r '.summary.skipped // 0' "$LATEST_REPORT")
    MISMATCHES=$(jq -r '.summary.ruleMismatchCount // 0' "$LATEST_REPORT")
    TOTAL=$(jq -r '.summary.totalCombinations // 0' "$LATEST_REPORT")

    echo ""
    info "========================================"
    info "Compatibility Test Results"
    info "========================================"
    ok   "Total:      $TOTAL"
    ok   "Passed:     $PASSED"
    error "Failed:     $FAILED"
    warn "Skipped:    $SKIPPED"
    warn "Mismatches: $MISMATCHES"
    info "Report:     $LATEST_REPORT"
    info "========================================"

    if [ "$MISMATCHES" -gt 0 ]; then
        echo ""
        warn "Rule mismatches detected:"
        jq -r '.ruleMismatches[] | "  [\(.coreType) \(.coreVersion)] \(.profileRemark): predicted=\(.rulePredicted), actual=\(.actualStatus)"' "$LATEST_REPORT" | head -20
        echo ""
    fi
else
    warn "No report JSON found in $TEST_REPORT_DIR"
fi

if [ $EXIT_CODE -ne 0 ]; then
    error "xcodebuild returned exit code $EXIT_CODE (some tests may have failed)"
fi

exit $EXIT_CODE
