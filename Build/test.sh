#!/bin/bash
# 打包,发布

APP_NAME="V2rayU"
INFOPLIST_FILE="Info.plist"
BASE_DIR=$HOME/swift/V2rayU
BUILD_DIR=${BASE_DIR}/Build
V2rayU_ARCHIVE=${BUILD_DIR}/V2rayU.xcarchive
V2rayU_RELEASE=${BUILD_DIR}/release
APP_Version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${BASE_DIR}/${APP_NAME}/${INFOPLIST_FILE}")
DMG_FINAL="${APP_NAME}.dmg"
APP_TITLE="${APP_NAME} - V${APP_Version}"
AppCastDir=$HOME/swift/appcast

function build() {
    echo "Building V2rayU."${APP_Version}
    echo "Cleaning up old archive & app..."
    rm -rf ${V2rayU_ARCHIVE} ${V2rayU_RELEASE}

    echo "Building archive... please wait a minute"
    xcodebuild -workspace ${BASE_DIR}/V2rayU.xcworkspace -config Release -scheme V2rayU -archivePath ${V2rayU_ARCHIVE} archive

    echo "Exporting archive..."
    xcodebuild -archivePath ${V2rayU_ARCHIVE} -exportArchive -exportPath ${V2rayU_RELEASE} -exportOptionsPlist ./build.plist

    echo "Cleaning up archive..."
    rm -rf ${V2rayU_ARCHIVE}

    chmod -R 755 "${V2rayU_RELEASE}/${APP_NAME}.app/Contents/Resources/v2ray-core"
    chmod -R 755 "${V2rayU_RELEASE}/${APP_NAME}.app/Contents/Resources/unzip.sh"
}

function createDmg() {
    umount "/Volumes/${APP_NAME}"

    ############# 1 #############
    APP_PATH="${V2rayU_RELEASE}/${APP_NAME}.app"
    DMG_BACKGROUND_IMG="dmg-bg@2x.png"

    DMG_TMP="${APP_NAME}-temp.dmg"

    # 清理文件夹
    echo "createDmg start."
    rm -rf "${DMG_TMP}" "${DMG_FINAL}"
    # 创建文件夹，拷贝，计算
    SIZE=`du -sh "${APP_PATH}" | sed 's/\([0-9\.]*\)M\(.*\)/\1/'`
    SIZE=`echo "${SIZE} + 1.0" | bc | awk '{print int($1+0.5)}'`
    # 容错处理
    if [ $? -ne 0 ]; then
       echo "Error: Cannot compute size of staging dir"
       exit
    fi
    # 创建临时dmg文件
    hdiutil create -srcfolder "${APP_PATH}" -volname "${APP_NAME}" -fs HFS+ \
          -fsargs "-c c=64,a=16,e=16" -format UDRW -size ${SIZE}M "${DMG_TMP}"
    echo "Created DMG: ${DMG_TMP}"

    ############# 2 #############
    DEVICE=$(hdiutil attach -readwrite -noverify "${DMG_TMP}"| egrep '^/dev/' | sed 1q | awk '{print $1}')

    # 拷贝背景图片
    mkdir /Volumes/"${APP_NAME}"/.background
    cp "${BUILD_DIR}/${DMG_BACKGROUND_IMG}" /Volumes/"${APP_NAME}"/.background/
    # 使用applescript设置一系列的窗口属性
    echo '
       tell application "Finder"
         tell disk "'${APP_NAME}'"
               open
               set current view of container window to icon view
               set toolbar visible of container window to false
               set statusbar visible of container window to false
               set the bounds of container window to {0, 0, 560, 297}
               set viewOptions to the icon view options of container window
               set arrangement of viewOptions to not arranged
               set icon size of viewOptions to 80
               set background picture of viewOptions to file ".background:'${DMG_BACKGROUND_IMG}'"
               make new alias file at container window to POSIX file "/Applications" with properties {name:"Applications"}
               delay 1
               set position of item "'${APP_NAME}'.app" of container window to {120, 120}
               set position of item "Applications" of container window to {380, 120}
               close
               open
               update without registering applications
               delay 2
         end tell
       end tell
    ' | osascript

    sync
    # 卸载
    hdiutil detach "${DEVICE}"

    ############# 3 #############
    echo "Creating compressed image"
    hdiutil convert "${DMG_TMP}" -format UDZO -imagekey zlib-level=9 -o "${DMG_FINAL}"

    # appcast sign update
    ${AppCastDir}/bin/sign_update ${DMG_FINAL}

    umount "/Volumes/${APP_NAME}"
}

function downloadV2ray() {
    echo "正在查询最新版v2ray ..."
    rm -fr v2ray-macos.zip v2ray-core
    tag=$(curl --silent "https://api.github.com/repos/v2ray/v2ray-core/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    echo "v2ray-core version: ${tag}"
    url="https://github.com/v2ray/v2ray-core/releases/download/${tag}/v2ray-macos.zip"
    echo "正在下载最新版v2ray: ${tag}"
    curl -Lo v2ray-macos.zip ${url}

    unzip -o v2ray-macos.zip -d v2ray-core
    rm -fr v2ray-macos.zip
}

echo "正在打包版本: V"${APP_Version}
read -n1 -r -p "请确认版本号是否正确 [Y/N]? " answer
case ${answer} in
Y | y ) echo
        echo "你选择了Y";;
N | n ) echo
        echo ""
        echo "OK, goodbye"
        exit;;
*)
        echo ""
        echo "请输入Y|N"
        exit;;
esac

rm -fr ${DMG_FINAL} ${V2rayU_RELEASE}
updatePlistVersion
downloadV2ray
build
createDmg
read -p "请输入版本描述: " release_note
pushRelease ${release_note}
generateAppcast ${release_note}
commit
rm -rf "${DMG_TMP}" "${APP_PATH}" "${V2rayU_RELEASE}"
echo "Done"
