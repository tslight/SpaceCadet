#!/usr/bin/env bash
set -euo pipefail

# Generates macOS AppIcon and StatusBar icon PNGs from source SVG/PNG files.
# Usage:
#   ./scripts/gen-appicon.sh source.png|source.svg
#   ./scripts/gen-appicon.sh --symbol keyboard.badge.ellipsis
#   ./scripts/gen-appicon.sh --statusbar source.svg
# Output written into SpaceCadetApp/SpaceCadetApp/Assets.xcassets/{AppIcon,StatusBarIcon}.appiconset
# Requires: sips (macOS), Swift (for symbol mode), rsvg-convert (for SVG), and ImageMagick 'convert' (optional).

APPICON_DIR="SpaceCadetApp/SpaceCadetApp/Assets.xcassets/AppIcon.appiconset"
STATUSBAR_DIR="SpaceCadetApp/SpaceCadetApp/Assets.xcassets/StatusBarIcon.imageset"
SIZES=(16 32 64 128 256 512 1024)
STATUSBAR_SIZES=(32 64)  # 32@1x and 64@2x

usage() {
  grep '^#' "$0" | sed 's/^#//' | sed '1,2d'
  exit 1
}

if [[ $# -lt 1 ]]; then
  usage
fi

SYMBOL=""
SRC=""
IS_STATUSBAR=0

if [[ $1 == "--statusbar" ]]; then
  IS_STATUSBAR=1
  SRC="$2"
elif [[ $1 == "--symbol" ]]; then
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

# If source is SVG, rasterize to appropriate size first
if [[ "$SRC" == *.svg ]]; then
  if [[ $IS_STATUSBAR -eq 1 ]]; then
    echo "[gen-appicon] Rasterizing SVG to 64x64 for status bar"
    if command -v rsvg-convert >/dev/null 2>&1; then
      rsvg-convert -w 64 -h 64 "$SRC" -o /tmp/statusbar-base.png
    elif command -v convert >/dev/null 2>&1; then
      convert -background none -density 64 "$SRC" -resize 64x64 /tmp/statusbar-base.png
    else
      echo "Please install librsvg (rsvg-convert) or ImageMagick (convert) to rasterize SVG." >&2
      exit 1
    fi
    SRC="/tmp/statusbar-base.png"
  else
    echo "[gen-appicon] Rasterizing SVG to 1024x1024 for app icon"
    if command -v rsvg-convert >/dev/null 2>&1; then
      rsvg-convert -w 1024 -h 1024 "$SRC" -o /tmp/icon-1024.png
    elif command -v convert >/dev/null 2>&1; then
      convert -background none -density 512 "$SRC" -resize 1024x1024 -type TrueColorAlpha /tmp/icon-1024.png
    else
      echo "Please install librsvg (rsvg-convert) or ImageMagick (convert) to rasterize SVG." >&2
      exit 1
    fi
    SRC="/tmp/icon-1024.png"
  fi
fi

mkdir -p "$APPICON_DIR"

if [[ $IS_STATUSBAR -eq 1 ]]; then
  # Generate status bar icons (small template icons for menu bar)
  echo "[gen-appicon] Generating StatusBar icons..."
  mkdir -p "$STATUSBAR_DIR"
  
  # rsvg-convert produces RGBA with white strokes on transparent background
  # We need to invert so strokes are black (0) on white background (1) for 1-bit template
  # ImageMagick: invert colors then threshold to 1-bit
  if command -v convert >/dev/null 2>&1; then
    # Resize and invert colors (white → black) then threshold to 1-bit
    convert "$SRC" -resize 32x32 -channel A -separate +channel \
      \( +clone -negate \) -compose Over -composite -type Bilevel "$STATUSBAR_DIR/StatusBarIcon-32.png"
    convert "$SRC" -resize 64x64 -channel A -separate +channel \
      \( +clone -negate \) -compose Over -composite -type Bilevel "$STATUSBAR_DIR/StatusBarIcon-64.png"
  else
    # Fallback to sips
    sips -z 32 32 "$SRC" --out "$STATUSBAR_DIR/StatusBarIcon-32.png" >/dev/null
    sips -z 64 64 "$SRC" --out "$STATUSBAR_DIR/StatusBarIcon-64.png" >/dev/null
  fi
  
  echo "Generated $STATUSBAR_DIR/StatusBarIcon-32.png"
  echo "Generated $STATUSBAR_DIR/StatusBarIcon-64.png"
  
  # Clean up temp files
  rm -f /tmp/statusbar-base.png /tmp/statusbar-64.png
else
  # Generate app icons (full color, multiple sizes)
  echo "[gen-appicon] Generating AppIcon..."
  
  for size in "${SIZES[@]}"; do
    OUT="$APPICON_DIR/AppIcon-$size.png"
    # Prefer ImageMagick if present for better scaling
    if command -v convert >/dev/null 2>&1; then
      convert "$SRC" -resize ${size}x${size} -type TrueColorAlpha "$OUT"
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
fi

echo "Done. Replace generated images with custom artwork anytime and re-run this script."
