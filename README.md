# Space Cadet ⌨️ 🚀

[![CI](https://github.com/tslight/SpaceCadet/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/tslight/SpaceCadet/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/tag/tslight/SpaceCadet?label=release)](https://github.com/tslight/SpaceCadet/releases)
[![Downloads](https://img.shields.io/github/downloads/tslight/SpaceCadet/total)](https://github.com/tslight/SpaceCadet/releases)
[![License](https://img.shields.io/github/license/tslight/SpaceCadet)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS_12%2B-blue)](#)
[![Swift](https://img.shields.io/badge/Swift-6.1-orange)](#)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)](https://github.com/tslight/SpaceCadet/pulls)

Take **CTRL** of your **SPC**!

* Press and release space alone inserts a normal space.
* Hold space alone beyond the threshold (default 700 ms) turns it into Control.
* Space plus any other key (chord) immediately acts as Control + that key.

Inspired by years of Emacs usage & the "Space Cadet" keyboard that the Lisp machines it was written on came with.

On that keyboard the modifier layout looked like this:

`SUPER/WIN/CMD > META/ALT/OPT > CTRL >  S P A C E  < CTRL < META/ALT/OPT < SUPER/WIN/CMD`

Modifiers were symmetrical and the most used Control modifier was accessible with the thumbs.

On the modern Macbook keyboard we only have one Control key and it's a pinky job - ie) far from ideal for ergonomics.

Space Cadet recifies this horrible, RSI inducing experience and means that the Control key is given pride of place and can be pressed symmetrically with the thumbs whilst touch typing 😊.

This is especially useful on macOS given that readline/Emacs style bindings work all over the shop.

*Couldn't I just do this with Karabiner?*

Absolutely. However, I wanted a much more simple app that only did this one thing, and also to learn a bit about macOS development and explore the limits of "vibe" coding in a language I'm not familiar with.

## Features

* Pure Swift, uses `CGEventTap` (requires Accessibility permission).
* Single configurable knob: `SPACE_CADET_HOLD_MS` (default 700 ms).
* Adaptive tap timing logs help you choose a personal threshold (see stderr output).
* Status bar app with Preferences (slider) and Toggle Logging.
* LaunchAgent template for auto-start on login.

## Install

1. Download the latest DMG from the Releases page: `SpaceCadet.dmg`.
2. Open the DMG and drag “Space Cadet.app” to Applications.
3. Launch the app from Applications. When prompted, grant Accessibility permission (System Settings > Privacy & Security > Accessibility). If you don’t see the prompt, add the app manually.
4. Adjust your hold threshold in Preferences. You can toggle logging and use “Suggest Threshold” to approximate a good value.

### Build

To build the background status bar app in Xcode:

1. Open `SpaceCadetApp/SpaceCadetApp.xcodeproj` in Xcode.
2. Select the `SpaceCadetApp` scheme and hit Run (⌘R).
3. A status bar item (keyboard icon on macOS 11+, or ⌃␣ on older macOS) will appear. Menu items include:
	- Enabled/Disabled
	- Preferences… (hold threshold slider; applied immediately)
	- Restart Event Tap
	- Toggle Logging (enable/disable verbose logs)
	- Suggest Threshold (based on adaptive average)
	- Open README
	- Quit

Notes:

* The app requests Accessibility permission just like the CLI.
* The app runs as a background accessory (no dock icon), controlled from the status bar.
* Build requires full Xcode (not just Command Line Tools).
* Preferences… lets you adjust the hold threshold (150–800 ms). Saved in `UserDefaults` and applied immediately.
* Adaptive average tap time (shown in CLI/App logs) can guide choosing a threshold (menu action “Suggest Threshold”).
* Toggle Logging enables/disables verbose logs without restarting.
* “Restart Event Tap” menu item can recover if macOS disables the tap.

## Releases

Prebuilt artifacts are attached to GitHub Releases (when tags like `v0.1.0` are pushed):

- `SpaceCadet.dmg` — drag-and-drop installer (recommended)
- `SpaceCadet.zip` — zipped app bundle (optional)
- `.sha256` checksum files

Verify and install:

```zsh
# Verify checksums (optional)
shasum -a 256 -c SpaceCadet.dmg.sha256
shasum -a 256 -c SpaceCadet.zip.sha256

# Install from DMG (recommended)
open SpaceCadet.dmg  # then drag Space Cadet.app to Applications

# Alternatively, install from ZIP
unzip SpaceCadet.zip -d /Applications
# If Gatekeeper warns, right-click the app → Open → Open.
```

## Threshold Tuning

Use Preferences in the app to set your hold threshold (default 700 ms). Guidance:

* Look at "adaptive avg tap" logs; pick a threshold ~20–40 ms above that number.
* Lower threshold: space-alone becomes Control sooner.
* Higher threshold: more time to tap a space before it could become Control.

## Development

CLI build & run (for development/testing):

```zsh
swift build
swift run SpaceCadet
```

Release build:

```zsh
swift build -c release
./.build/release/SpaceCadet
```

Adjust threshold when running CLI via env var:

```zsh
SPACE_CADET_HOLD_MS=300 swift run SpaceCadet   # faster
SPACE_CADET_HOLD_MS=900 swift run SpaceCadet   # slower
```

### CLI LaunchAgent (optional)

Edit the plist template at `scripts/com.apple.space-cadet.plist` if needed, then:

```zsh
make release
make install-agent
```

Unload later:

```zsh
make unload-agent
```

## Troubleshooting

* No effect: Ensure Accessibility permission granted (System Settings > Privacy & Security > Accessibility).
* Can't get spaces (all become Control): Threshold may be too low; raise it (e.g. 400–500 ms).
* Control not engaging when holding space alone: Threshold may be too high or you released before it fired; lower it.
* Event tap disabled errors: System may throttle; relaunch or ensure machine isn't overloaded.

## Security / Permissions

The app only intercepts key events locally; it does not log or persist keystrokes. Review the source to verify behavior.

## Tests

Run unit tests:

```zsh
swift test
```

## App Icon

An asset catalog stub (`AppIcon.appiconset`) is included. To generate placeholder icons from an image or SF Symbol:

```zsh
./scripts/gen-appicon.sh path/to/source-1024.png
# or
./scripts/gen-appicon.sh --symbol keyboard.badge.ellipsis
```

Images are written into `SpaceCadetApp/SpaceCadetApp/Assets.xcassets/AppIcon.appiconset`. Replace them with your final artwork as desired.
