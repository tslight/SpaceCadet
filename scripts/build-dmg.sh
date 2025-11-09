#!/usr/bin/env bash
set -euo pipefail

# Build a drag-and-drop DMG with the Space Cadet app, Applications symlink,
# and an optional custom background image.
# Usage:
#   scripts/build-dmg.sh \
#      "/absolute/path/Space Cadet.app" \
#      artifacts/Space-Cadet-macOS.dmg \
#      [optional-background.png]

APP_PATH=${1:-}
OUT_DMG=${2:-}
BG_IMG_IN=${3:-}

if [[ -z "${APP_PATH}" || -z "${OUT_DMG}" ]]; then
  echo "Usage: $0 '/absolute/path/Space Cadet.app' /path/to/output.dmg [background.png]" >&2
  exit 2
fi

if [[ ! -d "${APP_PATH}" ]]; then
  echo "App not found: ${APP_PATH}" >&2
  exit 1
fi

VOLNAME="Space Cadet"
STAGE=$(mktemp -d -t spacecadet-dmg)
trap 'rm -rf "${STAGE}"' EXIT

APP_DIR="${STAGE}/${VOLNAME}"
mkdir -p "${APP_DIR}"
cp -R "${APP_PATH}" "${APP_DIR}/"
(cd "${APP_DIR}" && ln -s /Applications Applications)

# Optional background
if [[ -n "${BG_IMG_IN}" ]]; then
  mkdir -p "${APP_DIR}/.background"
  cp "${BG_IMG_IN}" "${APP_DIR}/.background/dmg_background.png"
fi

mkdir -p "$(dirname "${OUT_DMG}")"

# Create a temporary RW DMG to set Finder layout & background
TMP_DMG="${STAGE}/tmp.dmg"
hdiutil create -ov -fs HFS+ -srcfolder "${APP_DIR}" -volname "${VOLNAME}" -format UDRW "${TMP_DMG}" >/dev/null

# Attach the image
ATTACH_OUT=$(hdiutil attach -readwrite -noverify -noautoopen "${TMP_DMG}")
DEV=$(echo "${ATTACH_OUT}" | awk '/^\/dev\// {print $1; exit}')
MOUNT_POINT=$(echo "${ATTACH_OUT}" | awk '/Volumes\// {print $3; exit}')

# Configure Finder window via AppleScript
osascript <<EOF
tell application "Finder"
  tell disk "${VOLNAME}"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {100, 100, 860, 560}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 96
    try
      set background picture of viewOptions to file ".background:dmg_background.png"
    end try
    delay 0.2
    set position of file "Space Cadet.app" to {160, 300}
    set position of file "Applications" to {620, 300}
    update without registering applications
    delay 0.2
    close
    open
    delay 0.2
    update without registering applications
  end tell
end tell
EOF

# Detach with retries (Finder can briefly hold file locks)
for i in {1..5}; do
  if hdiutil detach "${DEV}" >/dev/null; then
    break
  fi
  sleep 1
done

# Convert to compressed image
hdiutil convert "${TMP_DMG}" -ov -format UDZO -imagekey zlib-level=9 -o "${OUT_DMG}" >/dev/null

echo "DMG created at ${OUT_DMG}"
