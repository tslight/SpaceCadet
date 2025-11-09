import CoreGraphics
import Foundation

// Entry point: set up event tap, install run loop, and start intercepting events.
// Only configurable parameter: hold threshold (SPACE_CADET_HOLD_MS)
let holdEnv = ProcessInfo.processInfo.environment["SPACE_CADET_HOLD_MS"]
let holdThresholdMs = Double(holdEnv ?? "") ?? 500.0  // default 500ms

let remapper = KeyRemapper(holdThresholdMs: holdThresholdMs)
let tap = EventTap(remapHandler: { event in
    return remapper.handle(event: event)
})
do {
    try tap.start()
    fputs("[SpaceCadet] hold threshold = \(holdThresholdMs) ms\n", stderr)
    RunLoop.current.run()
} catch {
    fputs("space-cadet: Failed to start event tap: \(error)\n", stderr)
    exit(1)
}
