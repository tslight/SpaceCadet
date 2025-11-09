#!/usr/bin/env bash
set -euo pipefail

# Generates macOS AppIcon PNGs from a source image or SF Symbol (via swift symbol rendering).
# Usage:
#   ./scripts/gen-appicon.sh source.png|source.svg
#   ./scripts/gen-appicon.sh --symbol keyboard.badge.ellipsis
# Output written into SpaceCadetApp/SpaceCadetApp/Assets.xcassets/AppIcon.appiconset
# Requires: sips (macOS), Swift (for symbol mode), and ImageMagick 'convert' if you want better resizing quality (optional).

APPICON_DIR="SpaceCadetApp/SpaceCadetApp/Assets.xcassets/AppIcon.appiconset"
SIZES=(16 32 64 128 256 512 1024)

usage() {
  grep '^#' "$0" | sed 's/^#//' | sed '1,2d'
  exit 1
}

if [[ $# -lt 1 ]]; then
  usage
fi

SYMBOL=""
SRC=""

if [[ $1 == "--symbol" ]]; then
  SYMBOL="$2"
else
  SRC="$1"
fi

if [[ -n "$SYMBOL" ]]; then
  echo "[gen-appicon] Rendering SF Symbol: $SYMBOL"
  cat > /tmp/render_symbol.swift <<'SWIFT'
import AppKit
import Foundation

let symbol = CommandLine.arguments[1]
if #available(macOS 11.0, *) {
    guard let img = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) else {
        fputs("Failed to load symbol\n", stderr)
        exit(1)
    }
    img.size = NSSize(width: 1024, height: 1024)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    img.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024))
    NSGraphicsContext.restoreGraphicsState()
    if let data = rep.representation(using: .png, properties: [:]) {
        try! data.write(to: URL(fileURLWithPath: "symbol-1024.png"))
    }
} else {
    fputs("SF Symbols require macOS 11+\n", stderr)
    exit(1)
}
SWIFT
  swift /tmp/render_symbol.swift "$SYMBOL"
  SRC="symbol-1024.png"
fi

if [[ ! -f "$SRC" ]]; then
  echo "Source image not found: $SRC" >&2
  exit 1
fi

# If source is SVG, rasterize to 1024x1024 PNG first
if [[ "$SRC" == *.svg ]]; then
  echo "[gen-appicon] Rasterizing SVG to 1024x1024"
  if command -v rsvg-convert >/dev/null 2>&1; then
    rsvg-convert -w 1024 -h 1024 "$SRC" -o /tmp/icon-1024.png
  elif command -v convert >/dev/null 2>&1; then
    convert -background none -density 512 "$SRC" -resize 1024x1024 /tmp/icon-1024.png
  else
    echo "Please install librsvg (rsvg-convert) or ImageMagick (convert) to rasterize SVG." >&2
    exit 1
  fi
  SRC="/tmp/icon-1024.png"
fi

mkdir -p "$APPICON_DIR"

for size in "${SIZES[@]}"; do
  OUT="$APPICON_DIR/AppIcon-$size.png"
  # Prefer ImageMagick if present for better scaling
  if command -v convert >/dev/null 2>&1; then
    convert "$SRC" -resize ${size}x${size} "$OUT"
  else
    sips -z $size $size "$SRC" --out "$OUT" >/dev/null
  fi
  echo "Generated $OUT"
  # Create scaled variants where required (e.g. 32 for 16@2x etc.) are already represented by listing sizes.
  # The Contents.json expects these filenames already.
  if [[ $size -eq 16 ]]; then
    cp "$OUT" "$APPICON_DIR/AppIcon-32.png"
  elif [[ $size -eq 32 ]]; then
    cp "$OUT" "$APPICON_DIR/AppIcon-64.png"
  elif [[ $size -eq 128 ]]; then
    cp "$OUT" "$APPICON_DIR/AppIcon-256.png"
  elif [[ $size -eq 256 ]]; then
    cp "$OUT" "$APPICON_DIR/AppIcon-512.png"
  elif [[ $size -eq 512 ]]; then
    cp "$OUT" "$APPICON_DIR/AppIcon-1024.png"
  fi
done

echo "Done. Replace generated images with custom artwork anytime and re-run this script."
