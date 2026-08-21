#!/bin/bash
set -e
cd "$(dirname "$0")/.."
mkdir -p Resources/Icon
TMP="$(mktemp -d)/AppIcon.iconset"
xcrun swift tools/MakeIcon.swift "$TMP" >/dev/null
iconutil -c icns "$TMP" -o Resources/Icon/AppIcon.icns
echo "Icono: Resources/Icon/AppIcon.icns"
