#!/bin/sh

set -eu

usage() {
    cat <<'EOF'
Usage:
  update-capability-rules.sh --base-url <remote-base-url> [--target-dir <dir>]
  update-capability-rules.sh --xray-url <url> --singbox-url <url> [--target-dir <dir>]

Examples:
  update-capability-rules.sh --base-url https://raw.githubusercontent.com/yanue/V2rayU/main/Build/capability-rules
  update-capability-rules.sh --xray-url https://raw.githubusercontent.com/yanue/V2rayU/main/Build/capability-rules/xray-capability-rules.json --singbox-url https://raw.githubusercontent.com/yanue/V2rayU/main/Build/capability-rules/singbox-capability-rules.json

Environment:
  V2RAYU_RULES_BASE_URL         Optional default base URL
  V2RAYU_RULES_XRAY_URL         Optional default xray URL
  V2RAYU_RULES_SINGBOX_URL      Optional default sing-box URL
  V2RAYU_RULES_TARGET_DIR       Optional default target dir (default: ~/.V2rayU/capability-rules)
EOF
}

BASE_URL="${V2RAYU_RULES_BASE_URL:-}"
XRAY_URL="${V2RAYU_RULES_XRAY_URL:-}"
SINGBOX_URL="${V2RAYU_RULES_SINGBOX_URL:-}"
TARGET_DIR="${V2RAYU_RULES_TARGET_DIR:-${HOME}/.V2rayU/capability-rules}"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --base-url)
            BASE_URL="$2"
            shift 2
            ;;
        --xray-url)
            XRAY_URL="$2"
            shift 2
            ;;
        --singbox-url)
            SINGBOX_URL="$2"
            shift 2
            ;;
        --target-dir)
            TARGET_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [ -n "$BASE_URL" ]; then
    XRAY_URL="${XRAY_URL:-${BASE_URL%/}/xray-capability-rules.json}"
    SINGBOX_URL="${SINGBOX_URL:-${BASE_URL%/}/singbox-capability-rules.json}"
fi

if [ -z "$XRAY_URL" ] || [ -z "$SINGBOX_URL" ]; then
    echo "Either --base-url or both --xray-url and --singbox-url must be provided." >&2
    usage >&2
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "curl is required." >&2
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is required for JSON validation." >&2
    exit 1
fi

mkdir -p "$TARGET_DIR"
TMP_DIR=$(mktemp -d)
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

validate_rules() {
    file_path="$1"
    expected_core="$2"
    python3 - "$file_path" "$expected_core" <<'PY'
import json
import sys
from pathlib import Path

file_path = Path(sys.argv[1])
expected_core = sys.argv[2]

data = json.loads(file_path.read_text(encoding='utf-8'))
if data.get('schemaVersion') not in {1, 2, 3, 4}:
    raise SystemExit(f"schemaVersion must be 1, 2, 3 or 4: {file_path}")
if data.get('core') != expected_core:
    raise SystemExit(f"core mismatch in {file_path}: {data.get('core')} != {expected_core}")
capabilities = data.get('capabilities')
if not isinstance(capabilities, list) or not capabilities:
    raise SystemExit(f"capabilities must be a non-empty array: {file_path}")
for index, capability in enumerate(capabilities):
    if not isinstance(capability, dict):
        raise SystemExit(f"capability[{index}] must be an object: {file_path}")
    for key in ('key', 'displayName', 'kind', 'rule'):
        if key not in capability:
            raise SystemExit(f"capability[{index}] missing {key}: {file_path}")
    rule = capability['rule']
    if not isinstance(rule, dict) or 'type' not in rule or 'note' not in rule:
        raise SystemExit(f"capability[{index}].rule must contain type and note: {file_path}")
    evidence = capability.get('evidence')
    if evidence is not None:
        if not isinstance(evidence, list) or not evidence:
            raise SystemExit(f"capability[{index}].evidence must be a non-empty array when present: {file_path}")
        for evidence_index, item in enumerate(evidence):
            if not isinstance(item, dict):
                raise SystemExit(f"capability[{index}].evidence[{evidence_index}] must be an object: {file_path}")
            for key in ('id', 'kind', 'statement', 'sourceTitle', 'sourceURL', 'quote'):
                if key not in item:
                    raise SystemExit(f"capability[{index}].evidence[{evidence_index}] missing {key}: {file_path}")
print(file_path)
PY
}

download_file() {
    url="$1"
    destination="$2"
    echo "Downloading $url"
    curl --fail --location --silent --show-error "$url" --output "$destination"
}

XRAY_TMP="$TMP_DIR/xray-capability-rules.json"
SINGBOX_TMP="$TMP_DIR/singbox-capability-rules.json"

download_file "$XRAY_URL" "$XRAY_TMP"
download_file "$SINGBOX_URL" "$SINGBOX_TMP"

validate_rules "$XRAY_TMP" "xray"
validate_rules "$SINGBOX_TMP" "sing-box"

mv "$XRAY_TMP" "$TARGET_DIR/xray-capability-rules.json"
mv "$SINGBOX_TMP" "$TARGET_DIR/singbox-capability-rules.json"

echo "Capability rules updated in $TARGET_DIR"
