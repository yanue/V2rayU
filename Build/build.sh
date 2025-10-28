#!/bin/bash
# 打包,发布

APP_NAME="V2rayU"
INFOPLIST_FILE="Info.plist"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
BUILD_DIR=${BASE_DIR}/Build
V2rayU_ARCHIVE=${BUILD_DIR}/V2rayU.xcarchive
V2rayU_RELEASE=${BUILD_DIR}/release
V2rayU_64_dmg=${BUILD_DIR}/V2rayU-64.dmg
V2rayU_arm64_dmg=${BUILD_DIR}/V2rayU-arm64.dmg
DMG_JSON=${BUILD_DIR}/appdmg.json
APP_Version=$(sed -n '/MARKETING_VERSION/{s/MARKETING_VERSION = //;s/;//;s/^[[:space:]]*//;p;q;}' ${BASE_DIR}/V2rayU.xcodeproj/project.pbxproj)

function build() {
    echo "Building V2rayU version ${APP_Version}"
    
    sleep 3
    
    echo "Cleaning up old archive & app..."
    rm -rf ${V2rayU_ARCHIVE} ${V2rayU_RELEASE}
    if [ $? -ne 0 ]; then
        echo "Error: Failed to clean up old archive & app"
        exit 1
    fi

    echo "Building archive... please wait a minute"
    # build universal app
    xcodebuild -workspace ${BASE_DIR}/V2rayU.xcworkspace -configuration Release -scheme V2rayU -archivePath ${V2rayU_ARCHIVE} archive ARCHS="arm64 x86_64" VALID_ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO
    if [ $? -ne 0 ]; then
        echo "Error: Failed to build archive"
        exit 1
    fi
    
    sleep 3
    
    echo "verifying archive..."
    
    # 判断 V2rayU.app 的架构是否为 "x86_64 arm64"
    v2rayUInfo="$(lipo -info ${V2rayU_ARCHIVE}/Products/Applications/V2rayU.app/Contents/MacOS/V2rayU)"
    if [[ "$v2rayUInfo" != *"x86_64 arm64"* ]]; then
        echo "Error: V2rayU.app is not x86_64: $v2rayUInfo"
        exit 1
    else
        echo "V2rayU.app architecture verified: $v2rayUInfo"
    fi

    # 判断 v2ray-core/v2ray 的架构是否为 "x86_64"
    v2rayInfo="$(lipo -info ${V2rayU_ARCHIVE}/Products/Applications/V2rayU.app/Contents/Resources/v2ray-core/v2ray)"
    if [[ "$v2rayInfo" != *"x86_64"* ]]; then
        echo "Error: v2ray file is not x86_64: $v2rayInfo"
        exit 1
    else
        echo "v2ray file architecture verified: $v2rayInfo"
    fi

    # 判断 v2ray-core/v2ray-arm64 的架构是否为 "arm64"
    v2rayArm64Info="$(lipo -info ${V2rayU_ARCHIVE}/Products/Applications/V2rayU.app/Contents/Resources/v2ray-core/v2ray-arm64)"
    if [[ "$v2rayArm64Info" != *"arm64"* ]]; then
        echo "Error: v2ray-arm64 file is not arm64: $v2rayArm64Info"
        exit 1
    else
        echo "v2ray-arm64 file verified: $v2rayArm64Info"
    fi

    echo "Copying .app to release directory..."
    mkdir -p ${V2rayU_RELEASE}
    cp -R "${V2rayU_ARCHIVE}/Products/Applications/${APP_NAME}.app" "${V2rayU_RELEASE}/${APP_NAME}.app"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to copy .app"
        exit 1
    fi

    echo "Cleaning up archive..."
    rm -rf ${V2rayU_ARCHIVE}
    if [ $? -ne 0 ]; then
        echo "Error: Failed to clean up archive"
        exit 1
    fi

    echo "Setting permissions for resources..."
    chmod -R 755 "${V2rayU_RELEASE}/${APP_NAME}.app/Contents/Resources/v2ray-core"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to set permissions for resources"
        exit 1
    fi
    
    echo "self Signing to the app..."
#    codesign --force --deep --sign "V2rayU" "${V2rayU_RELEASE}/${APP_NAME}.app"
    
    echo "Creating DMG file..."
    rm -f ${V2rayU_64_dmg}  ${V2rayU_arm64_dmg}
    
    appdmg ${DMG_JSON} "${V2rayU_64_dmg}"
    appdmg ${DMG_JSON} "${V2rayU_arm64_dmg}"
    
    echo "Signing DMG files..."
#    codesign --force --deep --sign "V2rayU" ${V2rayU_64_dmg}
#    codesign --force --deep --sign "V2rayU" ${V2rayU_arm64_dmg}

    echo "Build completed successfully."
}

build

echo 'done'
