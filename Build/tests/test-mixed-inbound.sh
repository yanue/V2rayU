#!/bin/bash
# Test which core versions support "mixed" inbound (protocol/type)
# Usage: bash Build/tests/test-mixed-inbound.sh [--xray|--sing-box|--all]
set -e

ARCH=$(uname -m)
[ "$ARCH" = "arm64" ] && XRAY_BIN="xray-arm64" || XRAY_BIN="xray-64"
[ "$ARCH" = "arm64" ] && SB_BIN="sing-box-arm64" || SB_BIN="sing-box-64"

TMP_DIR=$(mktemp -d)
XRAY_CONFIG="$TMP_DIR/xray-config.json"
SB_CONFIG="$TMP_DIR/sb-config.json"
STDOUT_LOG="$TMP_DIR/stdout.log"
STDERR_LOG="$TMP_DIR/stderr.log"

# Xray config: protocol: "mixed"
cat > "$XRAY_CONFIG" <<'EOF'
{
  "log": {"loglevel": "error"},
  "inbounds": [
    {
      "port": "11112",
      "listen": "127.0.0.1",
      "protocol": "mixed",
      "settings": {"udp": false},
      "tag": "mixed-in"
    }
  ],
  "outbounds": [
    {"protocol": "freedom", "tag": "direct"}
  ]
}
EOF

# sing-box config: type: "mixed"
cat > "$SB_CONFIG" <<'EOF'
{
  "log": {"level": "error"},
  "inbounds": [
    {
      "type": "mixed",
      "tag": "mixed-in",
      "listen": "127.0.0.1",
      "listen_port": 11112
    }
  ],
  "outbounds": [
    {"type": "direct", "tag": "direct"}
  ]
}
EOF

test_xray() {
    local BIN_DIR="$1"
    echo "=== Xray-core mixed inbound test ==="
    for V in $(ls "$BIN_DIR" | sort -V); do
        local BP="$BIN_DIR/$V/$XRAY_BIN"
        [ ! -x "$BP" ] && continue
        : > "$STDOUT_LOG" ; : > "$STDERR_LOG"
        "$BP" run -c "$XRAY_CONFIG" > "$STDOUT_LOG" 2> "$STDERR_LOG" &
        local PID=$!
        sleep 1.5
        kill "$PID" 2>/dev/null || true
        sleep 0.3
        kill -9 "$PID" 2>/dev/null || true
        wait "$PID" 2>/dev/null || true
        local C=$(cat "$STDOUT_LOG" "$STDERR_LOG")
        if echo "$C" | grep -q "unknown config id: mixed"; then
            echo "FAIL $V"
        elif echo "$C" | grep -qi "failed to start\|error\|panic"; then
            echo "FAIL $V (other: $(echo "$C" | grep -m1 -i "failed\|error\|panic"))"
        else
            echo "PASS $V"
        fi
    done
}

test_singbox() {
    local BIN_DIR="$1"
    echo "=== sing-box mixed inbound test ==="
    for V in $(ls "$BIN_DIR" | sort -V); do
        local BP="$BIN_DIR/$V/$SB_BIN"
        [ ! -x "$BP" ] && continue
        : > "$STDOUT_LOG" ; : > "$STDERR_LOG"
        "$BP" check -c "$SB_CONFIG" > "$STDOUT_LOG" 2> "$STDERR_LOG"
        local RC=$?
        local C=$(cat "$STDOUT_LOG" "$STDERR_LOG")
        if [ $RC -eq 0 ]; then
            echo "PASS $V"
        else
            echo "FAIL $V ($(echo "$C" | head -1))"
        fi
    done
}

BIN_BASE="$(cd "$(dirname "$0")/bin" && pwd)"
MODE="${1:---all}"

case "$MODE" in
    --xray)       test_xray "$BIN_BASE/xray-core" ;;
    --sing-box)   test_singbox "$BIN_BASE/sing-box" ;;
    --all|*)      test_xray "$BIN_BASE/xray-core"; echo; test_singbox "$BIN_BASE/sing-box" ;;
esac

rm -rf "$TMP_DIR"
