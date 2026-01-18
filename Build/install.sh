#!/bin/sh
set -x

USERNAME=$(logname)
APP_HOME_DIR="$HOME/.V2rayU"

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

# 替换并直接写入目标路径
sed "s#__SINGBOX_BIN__#$SINGBOX_BIN#g; s#__APP_HOME_DIR__#$APP_HOME_DIR#g" \
    ./plist/yanue.v2rayu.sing-box.plist | sudo tee /Library/LaunchDaemons/yanue.v2rayu.sing-box.plist > /dev/null

sed "s#__XRAYCORE_BIN__#$XRAYCORE_BIN#g; s#__APP_HOME_DIR__#$APP_HOME_DIR#g" \
    ./plist/yanue.v2rayu.xray-core.plist | sudo tee /Library/LaunchDaemons/yanue.v2rayu.xray-core.plist > /dev/null

sudo chown root:wheel /Library/LaunchDaemons/yanue.v2rayu.sing-box.plist
sudo chmod 644 /Library/LaunchDaemons/yanue.v2rayu.sing-box.plist
sudo chown root:wheel /Library/LaunchDaemons/yanue.v2rayu.xray-core.plist
sudo chmod 644 /Library/LaunchDaemons/yanue.v2rayu.xray-core.plist

sudo /bin/launchctl unload -wF /Library/LaunchDaemons/yanue.v2rayu.sing-box.plist
sudo /bin/launchctl unload -wF /Library/LaunchDaemons/yanue.v2rayu.xray-core.plist
sudo /bin/launchctl load -wF /Library/LaunchDaemons/yanue.v2rayu.xray-core.plist
sudo /bin/launchctl load -wF /Library/LaunchDaemons/yanue.v2rayu.sing-box.plist

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
# sudoers 条目
ENTRY="# generate by V2rayU install.sh
${USERNAME} ALL=(root) NOPASSWD: /bin/launchctl load -wF /Library/LaunchDaemons/yanue.v2rayu.sing-box.plist
${USERNAME} ALL=(root) NOPASSWD: /bin/launchctl unload /Library/LaunchDaemons/yanue.v2rayu.sing-box.plist
${USERNAME} ALL=(root) NOPASSWD: /bin/launchctl enable yanue.v2rayu.sing-box
${USERNAME} ALL=(root) NOPASSWD: /bin/launchctl disable yanue.v2rayu.sing-box
${USERNAME} ALL=(root) NOPASSWD: /bin/launchctl start yanue.v2rayu.sing-box
${USERNAME} ALL=(root) NOPASSWD: /bin/launchctl stop yanue.v2rayu.sing-box
${USERNAME} ALL=(root) NOPASSWD: /bin/launchctl load -wF /Library/LaunchDaemons/yanue.v2rayu.xray-core.plist
${USERNAME} ALL=(root) NOPASSWD: /bin/launchctl unload /Library/LaunchDaemons/yanue.v2rayu.xray-core.plist
${USERNAME} ALL=(root) NOPASSWD: /bin/launchctl enable yanue.v2rayu.xray-core
${USERNAME} ALL=(root) NOPASSWD: /bin/launchctl disable yanue.v2rayu.xray-core
${USERNAME} ALL=(root) NOPASSWD: /bin/launchctl start yanue.v2rayu.xray-core
${USERNAME} ALL=(root) NOPASSWD: /bin/launchctl stop yanue.v2rayu.xray-core
# end by V2rayU"

TARGET="/private/etc/sudoers.d/v2rayu-helper"

echo "$ENTRY" | sudo tee "$TARGET" > /dev/null
sudo chmod 440 "$TARGET"
sudo chown root:wheel "$TARGET"
sudo visudo -c -f "$TARGET"

echo 'done'
