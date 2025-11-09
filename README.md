# Space Cadet ⌨️ 🚀

[![CI](https://github.com/tslight/SpaceCadet/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/tslight/SpaceCadet/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/tag/tslight/SpaceCadet?label=release)](https://github.com/tslight/SpaceCadet/releases)
[![Downloads](https://img.shields.io/github/downloads/tslight/SpaceCadet/total)](https://github.com/tslight/SpaceCadet/releases)
[![License](https://img.shields.io/github/license/tslight/SpaceCadet)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS_12%2B-blue)](#)
[![Swift](https://img.shields.io/badge/Swift-6.1-orange)](#)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)](https://github.com/tslight/SpaceCadet/pulls)

Take **CTRL** of your **SPC**

* Press and release space alone inserts a normal space.
* Hold space alone beyond the threshold (default 700 ms) turns it into Control.
* Space plus any other key (chord) immediately acts as Control + that key.

Inspired by years of Emacs usage & the "Space Cadet" keyboard that the Lisp machines it was written on came with.

On that keyboard the modifier layout looked like this:

`SUPER > META > CTRL > SPACE < CTRL < META < SUPER`

So modifiers were symmetrical and the most used Control modifier was accessible with the thumbs. On the modern Macbook keyboard we only have one Control key and it's a pinky job - ie) far from ideal for ergonomics. Space Cadet recifies this horrible experience and means that the Control key is given pride of place and can be pressed symmetrically with the thumbs whilst touch typing.

## Features

* Pure Swift, uses `CGEventTap` (requires Accessibility permission).
* Single configurable knob: `SPACE_CADET_HOLD_MS` (default 700 ms).
* Adaptive tap timing logs help you choose a personal threshold (see stderr output).
* Status bar app with Preferences (slider) and Toggle Logging.
* LaunchAgent template for auto-start on login.

## Build & Run

```zsh
swift build
swift run SpaceCadet
```

Or release build:

```zsh
swift build -c release
./.build/release/SpaceCadet
```

Grant Accessibility permission when prompted (System Settings > Privacy & Security > Accessibility). If the prompt does not appear, manually add the built binary.

### macOS App (Status Bar)

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

Prebuilt binaries are attached to GitHub Releases when tags like `v0.1.0` are pushed:

- `SpaceCadet-cli-macos.tar.gz` — the CLI binary (SwiftPM release build)
- `SpaceCadetApp-macos.zip` — the status bar app bundle (`Space Cadet.app`)
- `.sha256` checksum files for both

Verify and install:

```zsh
# Verify checksums (optional but recommended)
shasum -a 256 -c SpaceCadet-cli-macos.tar.gz.sha256
shasum -a 256 -c SpaceCadetApp-macos.zip.sha256

# CLI
tar -xzf SpaceCadet-cli-macos.tar.gz
./SpaceCadet  # grant Accessibility on first run

# App
unzip SpaceCadetApp-macos.zip -d /Applications
# If Gatekeeper flags it as unsigned, right-click the app → Open → Open.
```

## Threshold Tuning

Run with default (700 ms):

```zsh
swift run SpaceCadet
```

Try a faster threshold (e.g. 300 ms):

```zsh
SPACE_CADET_HOLD_MS=300 swift run SpaceCadet
```

Or slower (e.g. 900 ms):

```zsh
SPACE_CADET_HOLD_MS=700 swift run SpaceCadet
```

Guidance:

* Look at "adaptive avg tap" logs; pick a threshold ~20–40 ms above that number.
* Lower threshold: space-alone becomes Control sooner.
* Higher threshold: more time to tap a space before it could become Control.

## LaunchAgent Installation

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
## App Icon

An asset catalog stub (`AppIcon.appiconset`) is included. To generate placeholder icons from an image or SF Symbol:

```zsh
./scripts/gen-appicon.sh path/to/source-1024.png
# or
./scripts/gen-appicon.sh --symbol keyboard.badge.ellipsis
```

Images are written into `SpaceCadetApp/SpaceCadetApp/Assets.xcassets/AppIcon.appiconset`. Replace them with your final artwork as desired.


Run unit tests:

```zsh
swift test
```

## License

MIT — see `LICENSE`.
