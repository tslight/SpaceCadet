# Icon Generation Notes

## Status Bar Icon - CRITICAL ISSUE RESOLVED

### The Problem (Nov 9-10, 2025)
The status bar icon was displaying as a **blank gray square** instead of a keyboard icon. Root cause: **all previous PNG icon files were completely blank** (pure white 1-bit grayscale with no actual content).

### Investigation Results
- Checked commits dating back to initial creation: all had blank 1-bit grayscale PNGs
- Icon file format: 32x32 @1x, 64x64 @2x, 1-bit grayscale, 100% white pixels (0 black pixels)
- When rendered as macOS template icons, blank images show as empty gray squares

### Solution (Commit: eda9c31)
Created actual keyboard icons from SVG source with visible content:
- Black keyboard outline (rounded rectangle)
- Key grid pattern (3 rows of keys + spacebar area)
- Saved as 8-bit RGBA PNG (not 1-bit grayscale)
- Renders properly in macOS status bar

### AppDelegate Changes
Added explicit icon sizing to prevent macOS auto-scaling:
```swift
icon.size = NSSize(width: 18, height: 18)
```

### SVG Source Pattern (for future reference)
If regenerating icons, use this SVG structure:
```xml
<svg width="32" height="32" viewBox="0 0 32 32">
  <!-- Keyboard outline -->
  <rect x="2" y="6" width="28" height="20" rx="2" stroke="black" stroke-width="1.5"/>
  
  <!-- Key rows -->
  <g stroke="black" stroke-width="1">
    <!-- 3 rows of keys + spacebar -->
  </g>
</svg>
```

Convert with: `rsvg-convert -w 32 -h 32 keyboard.svg -o StatusBarIcon-32.png`

### DO NOT
- ❌ Create blank 1-bit grayscale PNG files
- ❌ Try to "fix" template rendering with magic ImageMagick filters
- ❌ Use 1-bit color depth for status bar icons
- ❌ Generate icons without verifying actual visible content

### VERIFY BEFORE COMMITTING
```bash
magick identify -verbose StatusBarIcon-32.png | grep "Colors:"
# Should show: Colors: > 1 (not just white)
```

### Gen Script Notes
`scripts/gen-appicon.sh` is incomplete/broken. For app icon generation use:
- Input: `assets/keyboard_icon.svg` (colorful multi-color app icon)
- Process: `rsvg-convert` → PNG files (8 sizes) → `.icns` bundle
- For status bar: Keep using generated SVG from source, verify before commit
