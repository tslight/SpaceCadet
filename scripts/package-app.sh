#!/bin/bash
set -euo pipefail

# Usage: scripts/package-app.sh [build-type]
# build-type: release (default) or debug


BUILD_TYPE="${1:-release}"
PRODUCT_NAME="SpaceCadetApp"
APP_NAME="Space Cadet.app"
# Capitalize first letter of build type for path
if [ "$BUILD_TYPE" = "release" ]; then
  BUILD_DIR="Release"
else
  BUILD_DIR="Debug"
fi
APP_BUNDLE="build-app/Build/Products/${BUILD_DIR}/${APP_NAME}"
EXECUTABLE=".build/${BUILD_TYPE}/${PRODUCT_NAME}"
PLIST="SpaceCadetApp/SpaceCadetApp/Info.plist"
ASSETS="SpaceCadetApp/SpaceCadetApp/Assets.xcassets"

# Clean previous bundle
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy executable
cp "${EXECUTABLE}" "${APP_BUNDLE}/Contents/MacOS/${PRODUCT_NAME}"

# Copy Info.plist
cp "${PLIST}" "${APP_BUNDLE}/Contents/Info.plist"

# Validate Info.plist CFBundleExecutable matches actual executable name
PLIST_EXECUTABLE=$(plutil -extract CFBundleExecutable xml1 -o - "${APP_BUNDLE}/Contents/Info.plist" | grep '<string>' | sed -E 's/.*<string>(.*)<\/string>.*/\1/')
ACTUAL_EXECUTABLE=$(basename "${EXECUTABLE}")
if [ "$PLIST_EXECUTABLE" != "$ACTUAL_EXECUTABLE" ]; then
  echo "Error: Info.plist CFBundleExecutable ('$PLIST_EXECUTABLE') does not match actual executable ('$ACTUAL_EXECUTABLE')" >&2
  exit 1
fi

# Compile asset catalog (requires actool)
ACTOOL=$(xcrun -f actool)
if [ -d "${ASSETS}" ]; then
  "$ACTOOL" --compile "${APP_BUNDLE}/Contents/Resources" \
    --platform macosx \
    --minimum-deployment-target 12.0 \
    --app-icon AppIcon \
    --output-partial-info-plist /tmp/assetcatalog.plist \
    "${ASSETS}"
fi

# Copy any other resources here if needed

echo "App bundle created at: ${APP_BUNDLE}"
