#!/bin/sh

#  install.sh
#  V2rayU
#
#  Created by yanue on 2021/01/30.
#  Copyright © 2021 yanue. All rights reserved.

set -x

get_current_user() {
    # install.sh 通过 osascript "with administrator privileges" 以 root 运行
    # 此时 $USER=root, $SUDO_USER=空, 所以必须用其他方式获取真实用户

    # 策略1: stat /dev/console — 返回当前 GUI 登录用户（macOS 最常用方式）
    _candidate=$(stat -f "%Su" /dev/console 2>/dev/null)
    if [ -n "$_candidate" ] && [ "$_candidate" != "root" ]; then
        echo "$_candidate"
        return
    fi

    # 策略2: scutil — macOS 官方 API 获取 console user（注意: <<<是 bash 语法，用 echo | 代替）
    _candidate=$(echo "show State:/Users/ConsoleUser" | scutil 2>/dev/null | awk '/Name :/ { print $3 }')
    if [ -n "$_candidate" ] && [ "$_candidate" != "root" ] && [ "$_candidate" != "loginwindow" ]; then
        echo "$_candidate"
        return
    fi

    # 策略3: logname — 在 osascript 环境下经常失败，但作为备选
    _candidate=$(logname 2>/dev/null)
    if [ -n "$_candidate" ] && [ "$_candidate" != "root" ]; then
        echo "$_candidate"
        return
    fi

    # 策略4: $SUDO_USER — 仅在通过 sudo 调用时有效
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        echo "$SUDO_USER"
        return
    fi

    echo ""
}

USERNAME="${USERNAME:-$(get_current_user)}"

# 安全检查：USERNAME 不能为空，否则会导致路径错误和 sudoers 安全漏洞
if [ -z "$USERNAME" ]; then
    echo "ERROR: Cannot determine current user. Aborting."
    exit 1
fi

# 验证用户存在
if ! id "$USERNAME" >/dev/null 2>&1; then
    echo "ERROR: User '$USERNAME' does not exist. Aborting."
    exit 1
fi

# ====== 目录定义 ======
# 用户数据目录：config, logs, db, pac（用户进程读写）
APP_HOME_DIR="/Users/$USERNAME/.V2rayU"
# 系统二进制目录：核心、工具（root 所有，用户只读+执行）
APP_BIN_ROOT="/usr/local/v2rayu"
# root daemon 日志目录
APP_LOG_DIR="/var/log/v2rayu"

# ====== 创建目录 ======
# install.sh 以 root 运行，必须用 sudo -u 切回用户来创建用户目录，否则 owner 变成 root
sudo -u "$USERNAME" mkdir -p "$APP_HOME_DIR"
mkdir -p "$APP_BIN_ROOT/bin"
mkdir -p "$APP_LOG_DIR"

# ====== 复制二进制到系统目录 ======
# V2rayUTool
sudo rm -rf "$APP_BIN_ROOT/V2rayUTool"
sudo cp -f ./V2rayUTool "$APP_BIN_ROOT/"

# bin 文件 (xray-core, sing-box)
sudo rm -rf "$APP_BIN_ROOT/bin/"
sudo cp -rf ./bin/ "$APP_BIN_ROOT/bin/"

# ====== 清理旧版残留（从 ~/.V2rayU 迁移到 /usr/local/v2rayu）======
rm -rf "$APP_HOME_DIR/V2rayUTool"
rm -rf "$APP_HOME_DIR/bin/"

ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    SINGBOX_BIN="$APP_BIN_ROOT/bin/sing-box/sing-box-arm64"
    XRAYCORE_BIN="$APP_BIN_ROOT/bin/xray-core/xray-arm64"
else
    SINGBOX_BIN="$APP_BIN_ROOT/bin/sing-box/sing-box-64"
    XRAYCORE_BIN="$APP_BIN_ROOT/bin/xray-core/xray-64"
fi

# 安装 tun-helper plist (LaunchDaemon - root权限)
sed "s#__SINGBOX_BIN__#$SINGBOX_BIN#g; s#__APP_HOME_DIR__#$APP_HOME_DIR#g" \
    ./plist/yanue.v2rayu.tun-helper.plist | sudo tee /Library/LaunchDaemons/yanue.v2rayu.tun-helper.plist > /dev/null

sudo chown root:wheel /Library/LaunchDaemons/yanue.v2rayu.tun-helper.plist
sudo chmod 644 /Library/LaunchDaemons/yanue.v2rayu.tun-helper.plist

sudo /bin/launchctl unload -wF /Library/LaunchDaemons/yanue.v2rayu.tun-helper.plist
sudo /bin/launchctl load -wF /Library/LaunchDaemons/yanue.v2rayu.tun-helper.plist

# pac 文件（以用户身份复制，保证 owner 正确）
if [ ! -d "$APP_HOME_DIR/pac" ]; then
    sudo -u "$USERNAME" cp -rf ./pac "$APP_HOME_DIR/"
fi

# ====== 权限设置 ======

# 1. 用户数据目录：归用户所有（app 进程读写 config.json, *.log, .db 等）
sudo chown -R "$USERNAME:staff" "$APP_HOME_DIR"
sudo chmod -R 755 "$APP_HOME_DIR"

# 2. 系统二进制目录：root:wheel（防止非 root 篡改核心二进制）
sudo chown -R root:wheel "$APP_BIN_ROOT"
sudo chmod -R 755 "$APP_BIN_ROOT"

# 3. V2rayUTool：root:admin + setuid（特权工具，设置系统代理等）
sudo chown root:admin "$APP_BIN_ROOT/V2rayUTool"
sudo chmod a+rxs "$APP_BIN_ROOT/V2rayUTool"

# 4. 用户日志文件（以用户身份创建，LaunchAgent 以用户身份运行）
sudo -u "$USERNAME" touch "$APP_HOME_DIR/core.log" "$APP_HOME_DIR/V2rayU.log"

# 5. root daemon 日志（tun-helper LaunchDaemon 以 root 运行）
sudo touch "$APP_LOG_DIR/tun.log"
sudo chown root:wheel "$APP_LOG_DIR/tun.log"
sudo chmod 644 "$APP_LOG_DIR/tun.log"   # root 可写, 用户可读

# 6. 去除隔离标记
sudo /usr/bin/xattr -rd com.apple.quarantine "$APP_BIN_ROOT/"
sudo /usr/bin/xattr -rd com.apple.quarantine "$APP_HOME_DIR/"

# sudoers 条目 (tun-helper + core 更新权限)
ENTRY="# generate by V2rayU install.sh
${USERNAME} ALL=(root) NOPASSWD: /Library/PrivilegedHelperTools/yanue.v2rayu.tun-helper.sh *
${USERNAME} ALL=(root) NOPASSWD: /bin/launchctl load -wF /Library/LaunchDaemons/yanue.v2rayu.tun-helper.plist
${USERNAME} ALL=(root) NOPASSWD: /bin/launchctl unload /Library/LaunchDaemons/yanue.v2rayu.tun-helper.plist
${USERNAME} ALL=(root) NOPASSWD: /bin/launchctl enable yanue.v2rayu.tun-helper
${USERNAME} ALL=(root) NOPASSWD: /bin/launchctl disable yanue.v2rayu.tun-helper
${USERNAME} ALL=(root) NOPASSWD: /bin/launchctl start yanue.v2rayu.tun-helper
${USERNAME} ALL=(root) NOPASSWD: /bin/launchctl stop yanue.v2rayu.tun-helper
# mv 重命名 (core 更新时)
${USERNAME} ALL=(root) NOPASSWD: /bin/mv ${APP_BIN_ROOT}/bin/xray-core/xray ${APP_BIN_ROOT}/bin/xray-core/xray-64
${USERNAME} ALL=(root) NOPASSWD: /bin/mv ${APP_BIN_ROOT}/bin/xray-core/xray ${APP_BIN_ROOT}/bin/xray-core/xray-arm64
# 设置核心文件权限 (core 更新后)
${USERNAME} ALL=(root) NOPASSWD: /bin/chown -R root\:wheel ${APP_BIN_ROOT}/bin
${USERNAME} ALL=(root) NOPASSWD: /bin/chown -R root\:wheel ${APP_BIN_ROOT}/bin/*
${USERNAME} ALL=(root) NOPASSWD: /bin/chmod -R 755 ${APP_BIN_ROOT}/bin
${USERNAME} ALL=(root) NOPASSWD: /bin/chmod -R 755 ${APP_BIN_ROOT}/bin/*
# 备份/恢复核心文件 (core 更新时)
${USERNAME} ALL=(root) NOPASSWD: /bin/rm -rf ${APP_BIN_ROOT}/bin/xray-core.bak
${USERNAME} ALL=(root) NOPASSWD: /bin/rm -rf ${APP_BIN_ROOT}/bin/xray-core
${USERNAME} ALL=(root) NOPASSWD: /bin/cp -rf ${APP_BIN_ROOT}/bin/xray-core ${APP_BIN_ROOT}/bin/xray-core.bak
${USERNAME} ALL=(root) NOPASSWD: /bin/cp -rf ${APP_BIN_ROOT}/bin/xray-core.bak ${APP_BIN_ROOT}/bin/xray-core
# unzip 解压到 bin 目录 (core 更新时)
${USERNAME} ALL=(root) NOPASSWD: /usr/bin/unzip -o * -d ${APP_BIN_ROOT}/bin/xray-core
# xattr 去除 quarantine
${USERNAME} ALL=(root) NOPASSWD: /usr/bin/xattr -rd com.apple.quarantine ${APP_BIN_ROOT}
${USERNAME} ALL=(root) NOPASSWD: /usr/bin/xattr -rd com.apple.quarantine ${APP_BIN_ROOT}/*
${USERNAME} ALL=(root) NOPASSWD: /usr/bin/xattr -rd com.apple.quarantine ${APP_HOME_DIR}
${USERNAME} ALL=(root) NOPASSWD: /usr/bin/xattr -rd com.apple.quarantine ${APP_HOME_DIR}/*
# 清空 tun.log (root 所有)
${USERNAME} ALL=(root) NOPASSWD: /bin/cp /dev/null ${APP_LOG_DIR}/tun.log
# end by V2rayU"

TARGET="/private/etc/sudoers.d/v2rayu-helper"
TMPFILE=$(mktemp)

echo "$ENTRY" > "$TMPFILE"
chmod 440 "$TMPFILE"
chown root:wheel "$TMPFILE"

# 先验证语法，再安装。避免写入有语法错误的 sudoers 导致 sudo 失效
if sudo visudo -c -f "$TMPFILE"; then
    sudo cp -f "$TMPFILE" "$TARGET"
    sudo chmod 440 "$TARGET"
    sudo chown root:wheel "$TARGET"
else
    echo "ERROR: sudoers syntax check failed. Not installing."
    rm -f "$TMPFILE"
    exit 1
fi
rm -f "$TMPFILE"

echo 'done'
