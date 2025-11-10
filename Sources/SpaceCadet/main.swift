import CoreGraphics
import Foundation
import Dispatch

// Entry point: set up event tap, install run loop, and start intercepting events.
// Only configurable parameter: hold threshold (SPACE_CADET_HOLD_MS)
let holdEnv = ProcessInfo.processInfo.environment["SPACE_CADET_HOLD_MS"]
let holdThresholdMs = Double(holdEnv ?? "") ?? 700.0  // default 700ms

let remapper = KeyRemapper(holdThresholdMs: holdThresholdMs)
let tap = EventTap(remapHandler: { event in remapper.handle(event: event) })

// Set up signal handlers for graceful shutdown
let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT)
let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM)

sigintSource.setEventHandler {
    fputs("[SpaceCadet] received SIGINT, shutting down gracefully\n", stderr)
    exit(0)
}

sigtermSource.setEventHandler {
    fputs("[SpaceCadet] received SIGTERM, shutting down gracefully\n", stderr)
    exit(0)
}

sigintSource.resume()
sigtermSource.resume()

do {
    try tap.start()
    fputs("[SpaceCadet] hold threshold = \(holdThresholdMs) ms\n", stderr)
    RunLoop.current.run()
} catch {
    fputs("space-cadet: Failed to start event tap: \(error)\n", stderr)
    exit(1)
}
