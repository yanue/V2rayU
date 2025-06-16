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
    lipo -info ${V2rayU_ARCHIVE}/Products/Applications/V2rayU.app/Contents/MacOS/V2rayU
    
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
