#!/bin/bash
set -e

APP_NAME="Markport"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

rm -rf "${BUILD_DIR}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

echo "Compiling..."
xcrun swiftc \
    -O -wmo \
    -parse-as-library \
    -o "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" \
    $(find src -name '*.swift' | sort) \
    -framework AppKit \
    -framework Foundation \
    -framework CoreText \
    -framework WebKit \
    -framework SwiftUI \
    -framework UniformTypeIdentifiers

cp Info.plist "${APP_BUNDLE}/Contents/Info.plist"

if [ ! -f Resources/Icon/AppIcon.icns ]; then
    echo "Generating icon..."
    bash tools/make-icon.sh
fi
cp Resources/Icon/AppIcon.icns "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"

echo "Signing app..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "Done: ${APP_BUNDLE}"
