#!/bin/bash
set -euo pipefail

APP_NAME="V2rayU"
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
    rm -rf ${V2rayU_ARCHIVE} ${V2rayU_RELEASE} ${V2rayU_64_dmg} ${V2rayU_arm64_dmg}
    if [ $? -ne 0 ]; then
        echo "Error: Failed to clean up old archive & app"
        exit 1
    fi

    # 2) build universal app
    xcodebuild -project "${BASE_DIR}/V2rayU.xcodeproj"  -configuration Release -scheme V2rayU -archivePath ${V2rayU_ARCHIVE} archive ARCHS="arm64 x86_64" VALID_ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO
    echo "Copying .app to release directory..."
    sleep 3

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
    chmod -R 755 "${V2rayU_RELEASE}/${APP_NAME}.app/Contents/Resources/bin"
    if [ $? -ne 0 ]; then
      echo "Error: Failed to set permissions for resources"
      exit 1
    fi

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
