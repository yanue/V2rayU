#!/bin/bash
set -euo pipefail

APP_NAME="V2rayU"
SCHEME="V2rayU"
CONFIGURATION="Release"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_PATH="${BASE_DIR}/V2rayU.xcodeproj"
BUILD_DIR="${BASE_DIR}/Build"
OUTPUT_DIR="${BUILD_DIR}/output"
DERIVED_DATA_PATH="${BUILD_DIR}/DerivedData"
SOURCE_PACKAGES_DIR="${BUILD_DIR}/SourcePackages"
PRODUCTS_DIR="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}"
BUILT_APP_PATH="${PRODUCTS_DIR}/${APP_NAME}.app"
APP_PATH="${OUTPUT_DIR}/${APP_NAME}.app"
REFRESH_DEPS=0

usage() {
  cat <<EOF
Usage: ./build.sh [--refresh-deps]

Options:
  -r, --refresh-deps   Clear local Swift Package caches for this project and re-resolve dependencies.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -r|--refresh-deps)
      REFRESH_DEPS=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

echo "Building ${APP_NAME} (${CONFIGURATION}, arm64)..."

if [[ "${REFRESH_DEPS}" -eq 1 ]]; then
  echo "Refreshing Swift Package dependencies..."
  rm -rf "${SOURCE_PACKAGES_DIR}" "${DERIVED_DATA_PATH}/SourcePackages"
fi

mkdir -p "${OUTPUT_DIR}" "${SOURCE_PACKAGES_DIR}"
rm -rf "${APP_PATH}"
mkdir -p "${OUTPUT_DIR}"

XCODEBUILD_ARGS=(
  -project "${PROJECT_PATH}"
  -scheme "${SCHEME}"
  -configuration "${CONFIGURATION}"
  -destination "generic/platform=macOS"
  -derivedDataPath "${DERIVED_DATA_PATH}"
  -clonedSourcePackagesDirPath "${SOURCE_PACKAGES_DIR}"
  ARCHS="arm64"
  ONLY_ACTIVE_ARCH=YES
)

if [[ "${REFRESH_DEPS}" -eq 1 ]]; then
  xcodebuild "${XCODEBUILD_ARGS[@]}" -resolvePackageDependencies
else
  XCODEBUILD_ARGS+=(-disableAutomaticPackageResolution)
fi

xcodebuild "${XCODEBUILD_ARGS[@]}" build

if [ ! -d "${BUILT_APP_PATH}" ]; then
  echo "Build succeeded but ${BUILT_APP_PATH} was not found."
  exit 1
fi

cp -R "${BUILT_APP_PATH}" "${APP_PATH}"
chmod -R 755 "${APP_PATH}/Contents/Resources/bin"

echo "App built successfully:"
echo "${APP_PATH}"
