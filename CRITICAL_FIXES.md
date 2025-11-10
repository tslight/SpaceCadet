# Critical Fixes Applied (Nov 10, 2025)

## Problem
The app would lock up keyboard/mouse input after running for a while, and then respawn infinitely, making the system unresponsive.

## Root Causes Identified & Fixed

### 1. **State Machine Deadlock**
- **Issue**: When a chord (key pressed while space held) was detected, the code tried to transition to control but didn't always emit the synthetic Control DOWN event, leaving the state machine in an inconsistent state.
- **Fix**: Added explicit logging and ensured `transitionToControlIfNeeded()` is always called on chord detection.

### 2. **EventTap Silent Disabling**
- **Issue**: If events arrived faster than the callback could handle them, macOS would silently disable the event tap without notification.
- **Fix**: Added explicit handling for `.tapDisabledByTimeout` and `.tapDisabledByUserInput` events with automatic recovery.

### 3. **Infinite Respawn Loop**
- **Issue**: LaunchAgent had `KeepAlive=true`, so any crash would cause the app to respawn indefinitely, locking the system.
- **Fix**: Changed LaunchAgent's `KeepAlive` from `true` to `false`. The internal watchdog timer now handles recovery.

### 4. **Missing Watchdog Recovery**
- **Issue**: If the state machine got stuck (e.g., missed space-up event), there was no recovery mechanism.
- **Fix**: Added 30-second watchdog timer that automatically resets stuck states and releases control.

### 5. **Graceful Shutdown**
- **Issue**: No signal handlers for graceful shutdown when terminated.
- **Fix**: Added SIGINT/SIGTERM handlers for clean exit.

## Files Modified

1. **Sources/SpaceCadet/main.swift**
   - Added signal handlers for SIGINT/SIGTERM

2. **Sources/SpaceCadet/EventTap.swift**
   - Improved tap disable detection and recovery
   - Better event type filtering

3. **Sources/SpaceCadet/KeyRemapper.swift**
   - Added watchdog timer (30s timeout)
   - Improved chord detection logging
   - Added watchdog timer scheduling/cancellation
   - Cancel watchdog when returning to idle state

4. **scripts/com.apple.space-cadet.plist**
   - Changed `<key>KeepAlive</key><true/>` to `<false/>`

## Testing Recommendations

1. Run the app in debug mode first:
   ```bash
   swift run SpaceCadet
   ```

2. Test normal operation:
   - Tap space (should produce space)
   - Hold space and press keys (should add control)

3. Test recovery:
   - Start the app
   - Let it run for extended periods
   - Try to trigger edge cases with rapid key presses

4. Verify watchdog works:
   - Add debug output when watchdog fires
   - Monitor state transitions

## Next Steps

1. Test the fixed binary thoroughly before reinstalling the LaunchAgent
2. Monitor stderr logs for watchdog recovery events
3. Consider adding metrics collection to track state machine anomalies
