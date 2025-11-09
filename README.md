# space-cadet

Remap the macOS space bar so that:

* Press and release space alone inserts a normal space.
* Hold space alone beyond the threshold (default 500 ms) turns it into Control.
* Space plus any other key (chord) immediately acts as Control + that key.

Inspired by "Space Cadet" keyboard behavior.

## Features

* Pure Swift, uses `CGEventTap` (requires Accessibility permission).
* Single configurable knob: `SPACE_CADET_HOLD_MS` (default 500 ms).
* Adaptive tap timing logs help you choose a personal threshold (see stderr output).
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
3. A status bar item (⌃␣) will appear; click it for a small menu (Enable/Disable, README, Quit).

Notes:

* The app requests Accessibility permission just like the CLI.
* The app runs as a background accessory (no dock icon), controlled from the status bar.
* Build requires full Xcode (not just Command Line Tools).
* Preferences… lets you adjust the hold threshold (150–800 ms). Saved in `UserDefaults` and applied immediately.
* Adaptive average tap time (shown in CLI/App logs) can guide choosing a threshold (menu action “Suggest Threshold”).
* “Restart Event Tap” menu item can recover if macOS disables the tap.

## Threshold Tuning

Run with default (500 ms):

```zsh
swift run SpaceCadet
```

Try a faster threshold (e.g. 300 ms):

```zsh
SPACE_CADET_HOLD_MS=300 swift run SpaceCadet
```

Or slower (e.g. 700 ms):

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

Run unit tests:

```zsh
swift test
```

## License

MIT (add actual LICENSE file if distributing).
