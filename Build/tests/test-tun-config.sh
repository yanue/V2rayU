#!/bin/bash
# Test sing-box TUN config compatibility across all versions
# Tests:
#   1. Pre-1.11.0 format (sniff fields on inbound, no route sniff action)
#   2. 1.11.0+ format (no sniff fields on inbound, route rule sniff action)
#   3. The app's current version-adaptive config generation
# Usage: bash Build/tests/test-tun-config.sh

set -e

ARCH=$(uname -m)
[ "$ARCH" = "arm64" ] && BINARY="sing-box-arm64" || BINARY="sing-box-64"

BIN_DIR="$(cd "$(dirname "$0")/bin" && pwd)/sing-box"

TMP_DIR=$(mktemp -d)
STDOUT_LOG="$TMP_DIR/stdout.log"
STDERR_LOG="$TMP_DIR/stderr.log"

CONFIG_OLD="$TMP_DIR/tun-old.json"
CONFIG_NEW="$TMP_DIR/tun-new.json"
CONFIG_APP="$TMP_DIR/tun-app.json"

# Pre-1.11.0 format: sniff fields on inbound, no route sniff action
cat > "$CONFIG_OLD" <<'EOF'
{
  "log": {"level": "warn", "output": "/dev/null", "timestamp": true},
  "dns": {
    "servers": [
      {"tag": "local-dns", "address": "223.5.5.5"},
      {"tag": "remote-dns", "address": "https://1.1.1.1/dns-query"}
    ],
    "rules": [
      {"domain_suffix": ".cn", "server": "local-dns"}
    ],
    "strategy": "prefer_ipv4"
  },
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "address": ["10.0.0.1/30"],
      "auto_route": true,
      "strict_route": true,
      "mtu": 1500,
      "stack": "system",
      "sniff": true,
      "sniff_override_destination": true
    }
  ],
  "outbounds": [
    {"type": "socks", "tag": "proxy", "server": "127.0.0.1", "server_port": 1080},
    {"type": "direct", "tag": "direct"}
  ],
  "route": {
    "auto_detect_interface": true,
    "default_domain_resolver": "local-dns",
    "rules": [
      {"outbound": "direct", "process_name": ["xray", "xray-64", "xray-arm64", "v2ray", "v2ray-core", "sing-box", "sing-box-arm64", "sing-box-64"]}
    ]
  }
}
EOF

# 1.11.0+ format: no sniff on inbound, route rule sniff action
cat > "$CONFIG_NEW" <<'EOF'
{
  "log": {"level": "warn", "output": "/dev/null", "timestamp": true},
  "dns": {
    "servers": [
      {"tag": "local-dns", "address": "223.5.5.5"},
      {"tag": "remote-dns", "address": "https://1.1.1.1/dns-query"}
    ],
    "rules": [
      {"domain_suffix": ".cn", "server": "local-dns"}
    ],
    "strategy": "prefer_ipv4"
  },
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "address": ["10.0.0.1/30"],
      "auto_route": true,
      "strict_route": true,
      "mtu": 1500,
      "stack": "system"
    }
  ],
  "outbounds": [
    {"type": "socks", "tag": "proxy", "server": "127.0.0.1", "server_port": 1080},
    {"type": "direct", "tag": "direct"}
  ],
  "route": {
    "auto_detect_interface": true,
    "default_domain_resolver": "local-dns",
    "rules": [
      {"action": "sniff"},
      {"outbound": "direct", "process_name": ["xray", "xray-64", "xray-arm64", "v2ray", "v2ray-core", "sing-box", "sing-box-arm64", "sing-box-64"]}
    ]
  }
}
EOF

# App-generated config (adaptive): copies CONFIG_OLD or CONFIG_NEW per version

echo "=== sing-box TUN config compatibility test ==="
echo ""

results_new=()
results_old=()
results_app=()

for V in $(ls "$BIN_DIR" | sort -V); do
    BP="$BIN_DIR/$V/$BINARY"
    [ ! -x "$BP" ] && continue

    # Parse version number for comparison
    MAJOR=$(echo "$V" | sed 's/^v//' | cut -d. -f1)
    MINOR=$(echo "$V" | sed 's/^v//' | cut -d. -f2)

    # App's logic: >= 1.11.0 uses new format, < 1.11.0 uses old format
    if [ "$MAJOR" -gt 1 ] || { [ "$MAJOR" -eq 1 ] && [ "$MINOR" -ge 11 ]; } 2>/dev/null; then
        cp "$CONFIG_NEW" "$CONFIG_APP"
        EXPECTED="new"
    else
        cp "$CONFIG_OLD" "$CONFIG_APP"
        EXPECTED="old"
    fi

    # Test with new config format (1.11.0+)
    : > "$STDOUT_LOG" ; : > "$STDERR_LOG"
    "$BP" check -c "$CONFIG_NEW" > "$STDOUT_LOG" 2> "$STDERR_LOG"
    if [ $? -eq 0 ]; then
        results_new+=("$V:pass")
    else
        results_new+=("$V:fail")
    fi
    NEW_ERR=$(cat "$STDERR_LOG" "$STDOUT_LOG" | head -1)

    # Test with old config format (pre-1.11.0)
    : > "$STDOUT_LOG" ; : > "$STDERR_LOG"
    "$BP" check -c "$CONFIG_OLD" > "$STDOUT_LOG" 2> "$STDERR_LOG"
    if [ $? -eq 0 ]; then
        results_old+=("$V:pass")
    else
        results_old+=("$V:fail")
    fi
    OLD_ERR=$(cat "$STDERR_LOG" "$STDOUT_LOG" | head -1)

    # Test with app's version-adaptive config
    : > "$STDOUT_LOG" ; : > "$STDERR_LOG"
    "$BP" check -c "$CONFIG_APP" > "$STDOUT_LOG" 2> "$STDERR_LOG"
    RC=$?
    APP_ERR=$(cat "$STDERR_LOG" "$STDOUT_LOG" | head -1)
    if [ $RC -eq 0 ]; then
        results_app+=("$V:pass")
        echo "PASS $V (app:${EXPECTED})"
    else
        results_app+=("$V:fail")
        echo "FAIL $V (app:${EXPECTED}) old:${OLD_ERR:0:60} new:${NEW_ERR:0:60}"
    fi
done

rm -rf "$TMP_DIR"

echo ""
echo "=== Summary ==="
echo ""

print_section() {
    local label="$1"; shift
    local items=("$@")
    local fail=0 pass=0
    for r in "${items[@]}"; do
        case "${r#*:}" in
            pass) ((pass++)) ;;
            fail) ((fail++)) ;;
        esac
    done
    echo "$label: pass=$pass fail=$fail"
}

print_section "New format (route sniff)" "${results_new[@]}"
print_section "Old format (inbound sniff)" "${results_old[@]}"
print_section "App adaptive config" "${results_app[@]}"

echo ""
echo "=== Details ==="
for i in "${!results_app[@]}"; do
    V=$(ls "$BIN_DIR" | sort -V | sed -n "$((i+1))p")
    A="${results_app[$i]}"
    N="${results_new[$i]}"
    O="${results_old[$i]}"
    echo "$V  app:${A#*:}  new:${N#*:}  old:${O#*:}"
done
