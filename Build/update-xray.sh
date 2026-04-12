#!/bin/sh
#
# update-xray.sh — 以 root 权限更新 xray-core 二进制
#
# 安装位置: /usr/local/v2rayu/update-xray.sh (root:wheel, 755)
# 调用方式: sudo -n /usr/local/v2rayu/update-xray.sh <zip_file>
#
# 参数:
#   $1  zip 文件路径 (下载的 xray-core 发布包)
#
# 流程: 备份 → 解压 → 重命名 → 权限 → 去隔离 → 清理
# 失败时自动回滚到备份版本
#
# 退出码:
#   0  成功
#   1  失败 (错误信息输出到 stderr)

# ---------- 常量 ----------
BIN_ROOT="/usr/local/v2rayu"
XRAY_DIR="${BIN_ROOT}/bin/xray-core"
XRAY_BAK="${XRAY_DIR}.bak"

# ---------- 参数校验 ----------
ZIP_FILE="$1"

die() { echo "ERROR: $*" >&2; exit 1; }

[ -z "$ZIP_FILE" ] && die "Usage: $0 <zip_file>"
[ -f "$ZIP_FILE" ] || die "zip file not found: $ZIP_FILE"

# ---------- 检测架构 ----------
case "$(uname -m)" in
    arm64)  XRAY_BIN="xray-arm64" ;;
    x86_64) XRAY_BIN="xray-64"    ;;
    *)      die "unsupported arch: $(uname -m)" ;;
esac

# ---------- 回滚 ----------
rollback() {
    if [ -d "$XRAY_BAK" ]; then
        rm -rf "$XRAY_DIR" 2>/dev/null
        mv "$XRAY_BAK" "$XRAY_DIR"
        echo "Rolled back to previous version" >&2
    fi
    die "$1"
}

# ---------- 1. 备份当前版本 ----------
rm -rf "$XRAY_BAK" 2>/dev/null
[ -d "$XRAY_DIR" ] && cp -a "$XRAY_DIR" "$XRAY_BAK"

# ---------- 2. 解压 ----------
/usr/bin/unzip -o "$ZIP_FILE" -d "$XRAY_DIR" \
    || rollback "unzip failed"

# ---------- 3. 重命名 xray → xray-arm64 / xray-64 ----------
SRC="${XRAY_DIR}/xray"
DST="${XRAY_DIR}/${XRAY_BIN}"
if [ -f "$SRC" ] && [ "$SRC" != "$DST" ]; then
    mv -f "$SRC" "$DST" || rollback "rename failed"
fi

# 确认目标二进制存在
[ -f "$DST" ] || rollback "binary not found after unzip: $DST"

# ---------- 4. 权限 ----------
chown -R root:wheel "$XRAY_DIR"
chmod -R 755 "$XRAY_DIR"

# ---------- 5. 去除 macOS 隔离标记 ----------
/usr/bin/xattr -rd com.apple.quarantine "$BIN_ROOT" 2>/dev/null || true

# ---------- 6. 清理 ----------
rm -rf "$XRAY_BAK" 2>/dev/null
rm -f  "$ZIP_FILE"  2>/dev/null

echo "ok"

