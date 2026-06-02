#!/bin/sh
#
# update-singbox.sh — 以 root 权限更新 sing-box 二进制
#
# 安装位置: /usr/local/v2rayu/update-singbox.sh (root:wheel, 755)
# 调用方式: sudo -n /usr/local/v2rayu/update-singbox.sh <tar_gz_file>
#
# 参数:
#   $1  tar.gz 文件路径 (下载的 sing-box 发布包)
#
# 流程: 备份 → 解压 → 替换当前架构二进制 → 权限 → 去隔离 → 清理
# 失败时自动回滚到备份版本

BIN_ROOT="/usr/local/v2rayu"
SINGBOX_DIR="${BIN_ROOT}/bin/sing-box"
SINGBOX_BAK="${SINGBOX_DIR}.bak"

TAR_FILE="$1"

die() { echo "ERROR: $*" >&2; exit 1; }

[ -z "$TAR_FILE" ] && die "Usage: $0 <tar_gz_file>"
[ -f "$TAR_FILE" ] || die "tar.gz file not found: $TAR_FILE"

case "$(uname -m)" in
    arm64)  SINGBOX_BIN="sing-box-arm64" ;;
    x86_64) SINGBOX_BIN="sing-box-64"    ;;
    *)      die "unsupported arch: $(uname -m)" ;;
esac

rollback() {
    if [ -d "$SINGBOX_BAK" ]; then
        rm -rf "$SINGBOX_DIR" 2>/dev/null
        mv "$SINGBOX_BAK" "$SINGBOX_DIR"
        echo "Rolled back to previous version" >&2
    fi
    die "$1"
}

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/v2rayu-singbox.XXXXXX")" || die "mktemp failed"

cleanup() {
    rm -rf "$TMP_DIR" 2>/dev/null
}

trap cleanup EXIT INT TERM

rm -rf "$SINGBOX_BAK" 2>/dev/null
[ -d "$SINGBOX_DIR" ] && cp -a "$SINGBOX_DIR" "$SINGBOX_BAK"
mkdir -p "$SINGBOX_DIR" || rollback "create sing-box directory failed"

/usr/bin/tar -xzf "$TAR_FILE" -C "$TMP_DIR" || rollback "untar failed"

SRC="$(find "$TMP_DIR" -type f -name sing-box 2>/dev/null | head -n 1)"
[ -n "$SRC" ] && [ -f "$SRC" ] || rollback "binary not found after untar"

DST="${SINGBOX_DIR}/${SINGBOX_BIN}"
cp -f "$SRC" "$DST" || rollback "replace binary failed"

[ -f "$DST" ] || rollback "binary not found after replace: $DST"
chmod 755 "$DST" || rollback "chmod binary failed"

if command -v file >/dev/null 2>&1; then
    FILE_INFO="$(file "$DST" 2>/dev/null)"
    case "$(uname -m)" in
        arm64)
            echo "$FILE_INFO" | grep -q "arm64" || rollback "binary arch mismatch: $FILE_INFO"
            ;;
        x86_64)
            echo "$FILE_INFO" | grep -q "x86_64" || rollback "binary arch mismatch: $FILE_INFO"
            ;;
    esac
fi

chown -R root:wheel "$SINGBOX_DIR"
chmod -R 755 "$SINGBOX_DIR"

/usr/bin/xattr -rd com.apple.quarantine "$BIN_ROOT" 2>/dev/null || true

rm -rf "$SINGBOX_BAK" 2>/dev/null
rm -f "$TAR_FILE" 2>/dev/null

echo "ok"
