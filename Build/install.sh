#!/bin/sh

#  install.sh
#  V2rayU
#
#  Created by yanue on 2021/01/30.
#  Copyright © 2021 yanue. All rights reserved.

set -x

get_current_user() {
    _user=""

    for _candidate in "$USER" "$SUDO_USER" ""; do
        if [ -n "$_candidate" ] && [ "$_candidate" != "root" ]; then
            echo "$_candidate"
            return
        fi
    done

    _candidate=$(logname 2>/dev/null)
    if [ -n "$_candidate" ] && [ "$_candidate" != "root" ]; then
        echo "$_candidate"
        return
    fi

    _candidate=$(stat -f "%Su" /dev/console 2>/dev/null)
    if [ -n "$_candidate" ] && [ "$_candidate" != "root" ]; then
        echo "$_candidate"
        return
    fi

    echo ""
}

USERNAME="${USERNAME:-$(get_current_user)}"

APP_HOME_DIR="/Users/$USERNAME/.V2rayU"

# 清理并复制工具
rm -rf "$APP_HOME_DIR/V2rayUTool"
cp -rf ./V2rayUTool "$APP_HOME_DIR/"

# 复制 bin 文件
rm -rf "$APP_HOME_DIR/bin/"
cp -rf ./bin/ "$APP_HOME_DIR/bin/"

ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    SINGBOX_BIN="$APP_HOME_DIR/bin/sing-box/sing-box-arm64"
    XRAYCORE_BIN="$APP_HOME_DIR/bin/xray-core/xray-arm64"
else
    SINGBOX_BIN="$APP_HOME_DIR/bin/sing-box/sing-box-64"
    XRAYCORE_BIN="$APP_HOME_DIR/bin/xray-core/xray-64"
fi

# 安装 tun-helper plist (LaunchDaemon - root权限)
sed "s#__SINGBOX_BIN__#$SINGBOX_BIN#g; s#__APP_HOME_DIR__#$APP_HOME_DIR#g" \
    ./plist/yanue.v2rayu.tun-helper.plist | sudo tee /Library/LaunchDaemons/yanue.v2rayu.tun-helper.plist > /dev/null

sudo chown root:wheel /Library/LaunchDaemons/yanue.v2rayu.tun-helper.plist
sudo chmod 644 /Library/LaunchDaemons/yanue.v2rayu.tun-helper.plist

sudo /bin/launchctl unload -wF /Library/LaunchDaemons/yanue.v2rayu.tun-helper.plist
sudo /bin/launchctl load -wF /Library/LaunchDaemons/yanue.v2rayu.tun-helper.plist

# pac 文件
if [ ! -d "$APP_HOME_DIR/pac" ]; then
    cp -rf ./pac "$APP_HOME_DIR/"
fi

# 权限
sudo chmod -R 755 "$APP_HOME_DIR"
sudo chown -R root:wheel "$APP_HOME_DIR/bin"
sudo chmod -R 777 "$APP_HOME_DIR/bin"

# 去除隔离标记
sudo /usr/bin/xattr -rd com.apple.quarantine "$APP_HOME_DIR/"

# 设置 V2rayUTool 为 root 可执行
cd $APP_HOME_DIR
tool="./V2rayUTool"
sudo chown root:admin "$tool"
sudo chmod a+rxs ${tool}

# sudoers 条目 (tun-helper + core 更新权限)
ENTRY="# generate by V2rayU install.sh
${USERNAME} ALL=(root) NOPASSWD: /Library/PrivilegedHelperTools/yanue.v2rayu.tun-helper.sh *
${USERNAME} ALL=(root) NOPASSWD: /bin/launchctl load -wF /Library/LaunchDaemons/yanue.v2rayu.tun-helper.plist
${USERNAME} ALL=(root) NOPASSWD: /bin/launchctl unload /Library/LaunchDaemons/yanue.v2rayu.tun-helper.plist
${USERNAME} ALL=(root) NOPASSWD: /bin/launchctl enable yanue.v2rayu.tun-helper
${USERNAME} ALL=(root) NOPASSWD: /bin/launchctl disable yanue.v2rayu.tun-helper
${USERNAME} ALL=(root) NOPASSWD: /bin/launchctl start yanue.v2rayu.tun-helper
${USERNAME} ALL=(root) NOPASSWD: /bin/launchctl stop yanue.v2rayu.tun-helper
# mv 重命名
${USERNAME} ALL=(root) NOPASSWD: /bin/mv ${APP_HOME_DIR}/bin/xray-core/xray ${APP_HOME_DIR}/bin/xray-core/xray-64
${USERNAME} ALL=(root) NOPASSWD: /bin/mv ${APP_HOME_DIR}/bin/xray-core/xray ${APP_HOME_DIR}/bin/xray-core/xray-arm64
# chmod root
${USERNAME} ALL=(root) NOPASSWD: /bin/chown -R root:wheel "$APP_HOME_DIR/bin/*"
${USERNAME} ALL=(root) NOPASSWD: /bin/chmod -R 777 "$APP_HOME_DIR/bin/*"
# xattr 去除 quarantine
${USERNAME} ALL=(root) NOPASSWD: /usr/bin/xattr -rd com.apple.quarantine ${APP_HOME_DIR}/*
# end by V2rayU"

TARGET="/private/etc/sudoers.d/v2rayu-helper"

echo "$ENTRY" | sudo tee "$TARGET" > /dev/null
sudo chmod 440 "$TARGET"
sudo chown root:wheel "$TARGET"
sudo visudo -c -f "$TARGET"

echo 'done'
