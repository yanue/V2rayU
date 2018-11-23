#!/bin/bash

APP_NAME="V2rayU"
INFOPLIST_FILE="Info.plist"
BASE_DIR=$HOME/swift/V2rayU
BUILD_DIR=${BASE_DIR}/Build
V2rayU_ARCHIVE=${BUILD_DIR}/V2rayU.xcarchive
V2rayU_RELEASE=${BUILD_DIR}/release
APP_Version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${BASE_DIR}/${APP_NAME}/${INFOPLIST_FILE}")
DMG_FINAL="${APP_NAME}-${APP_Version}.dmg"
APP_TITLE="${APP_NAME} - V${APP_Version}"

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
}

function createDmg() {
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
    echo "${DMG_BACKGROUND_IMG}";

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
               set the bounds of container window to {0, 0, 640, 400}
               set viewOptions to the icon view options of container window
               set arrangement of viewOptions to not arranged
               set icon size of viewOptions to 128
               set background picture of viewOptions to file ".background:'${DMG_BACKGROUND_IMG}'"
               make new alias file at container window to POSIX file "/Applications" with properties {name:"Applications"}
               delay 1
               set position of item "'${APP_NAME}'.app" of container window to {152, 256}
               set position of item "Applications" of container window to {460, 256}
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

    # 清理文件夹
    rm -rf "${DMG_TMP}"
}

function generateAppcast() {
    echo "pushRelease"
    // https://github.com/c9s/appcast.git
    appcast -append -title=${APP_TITLE}\
        -description=$1 -file ${DMG_FINAL} -url ${V2rayU_RELEASE}\
        -version ${APP_Version} -dsaSignature="blah"\
        -versionShortString=${APP_Version}\
        ./appcast.xml
}

function pushRelease() {
    github-release release\
        --user yanue\
        --repo ${APP_NAME}\
        --tag ${APP_Version}\
        --name ${APP_TITLE}\
        --description $1

    github-release upload
        --user yanue
        --repo ${APP_NAME}
        --tag ${APP_Version}
        --name ${DMG_FINAL}
        --file ${DMG_FINAL}

    git add Build/appcast.xml
    git commit -a -m "update version: "${APP_Version}
    git push
}

echo "正在打包版本: V"${APP_Version}
read -n1 -p "请确认版本号是否正确 [Y/N]? " answer
case ${answer} in
    Y | y ) echo
            echo "你选择了Y";;
    N | n ) echo
            echo OK, goodbye
            exit;;
esac

#build
#createDmg

read -p "请输入版本描述: " release_note
pushRelease ${release_note}
generateAppcast ${release_note}

echo "Done"
exit 0