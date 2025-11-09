#!/usr/bin/env bash
set -euo pipefail

# Build a drag-and-drop DMG with the Space Cadet app and Applications symlink.
# Usage:
#   scripts/build-dmg.sh "path/to/Space Cadet.app" artifacts/Space-Cadet-macOS.dmg

APP_PATH=${1:-}
OUT_DMG=${2:-}

if [[ -z "${APP_PATH}" || -z "${OUT_DMG}" ]]; then
  echo "Usage: $0 '/absolute/path/Space Cadet.app' /path/to/output.dmg" >&2
  exit 2
fi

if [[ ! -d "${APP_PATH}" ]]; then
  echo "App not found: ${APP_PATH}" >&2
  exit 1
fi

VOLNAME="Space Cadet"
STAGE=$(mktemp -d -t spacecadet-dmg)
trap 'rm -rf "${STAGE}"' EXIT

mkdir -p "${STAGE}/${VOLNAME}"
cp -R "${APP_PATH}" "${STAGE}/${VOLNAME}/"
(cd "${STAGE}/${VOLNAME}" && ln -s /Applications Applications)

mkdir -p "$(dirname "${OUT_DMG}")"

hdiutil create -volname "${VOLNAME}" -srcfolder "${STAGE}/${VOLNAME}" -ov -format UDZO -imagekey zlib-level=9 "${OUT_DMG}"

echo "DMG created at ${OUT_DMG}"
