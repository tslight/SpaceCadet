import CoreGraphics
import Foundation

enum EventTapError: Error, CustomStringConvertible {
    case cannotCreateTap
    case cannotCreateRunLoopSource
    case accessibilityMissing

    var description: String {
        switch self {
        case .cannotCreateTap: return "Unable to create CGEventTap."
        case .cannotCreateRunLoopSource: return "Unable to create CFMachPort run loop source."
        case .accessibilityMissing: return "Accessibility permissions are required."
        }
    }
}

final class EventTap {
    typealias Handler = (CGEvent) -> CGEvent?

    private let handler: Handler
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Expose the underlying CFMachPort for health checks (read-only)
    public var machPort: CFMachPort? { tap }

    /// Returns true if the tap is currently enabled (calls CGEvent.tapIsEnabled)
    public var isTapEnabled: Bool {
        guard let tap = tap else { return false }
        return CGEvent.tapIsEnabled(tap: tap)
    }

    init(remapHandler: @escaping Handler) {
        self.handler = remapHandler
    }

    func start() throws {
        fputs("[EventTap] starting...\n", stderr)
        // Note: kCGHIDEventTap intercepts at the HID level
        let mask =
            (1 << CGEventType.keyDown.rawValue | 1 << CGEventType.keyUp.rawValue | 1
                << CGEventType.flagsChanged.rawValue)

        fputs("[EventTap] mask = \(mask)\n", stderr)

        guard
            let tap = CGEvent.tapCreate(
                tap: .cghidEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: CGEventMask(mask),
                callback: EventTap.tapCallback,
                userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
            )
        else {
            fputs("[EventTap] ERROR: CGEvent.tapCreate failed!\n", stderr)
            throw EventTapError.cannotCreateTap
        }

        fputs("[EventTap] tap created successfully\n", stderr)

        guard let rls = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            fputs("[EventTap] ERROR: CFMachPortCreateRunLoopSource failed!\n", stderr)
            throw EventTapError.cannotCreateRunLoopSource
        }

        fputs("[EventTap] run loop source created\n", stderr)

        self.tap = tap
        self.runLoopSource = rls

        CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        fputs("[EventTap] enabled tap on main run loop\n", stderr)
    }

    private static let tapCallback: CGEventTapCallBack = { _, type, event, refcon in
        fputs("[EventTap.callback] fired! type=\(type.rawValue)\n", stderr)
        guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
        let mySelf = Unmanaged<EventTap>.fromOpaque(refcon).takeUnretainedValue()

        // Re-enable tap if disabled by timeout or user input
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            fputs("[EventTap.callback] tap was disabled! Attempting recovery...\n", stderr)
            if let liveTap = mySelf.tap {
                CGEvent.tapEnable(tap: liveTap, enable: true)
                fputs("[EventTap.callback] tap re-enabled\n", stderr)
            }
            return Unmanaged.passUnretained(event)
        }

        // Handle actual key events
        if type == .keyDown || type == .keyUp || type == .flagsChanged {
            fputs("[EventTap.callback] processing key event type=\(type.rawValue)\n", stderr)
            if let returned = mySelf.handler(event) {
                // If the handler returns the original event, don't retain it; if it
                // returns a newly created CGEvent, we must return a retained reference
                // so the system owns it for delivery.
                if returned === event {
                    return Unmanaged.passUnretained(returned)
                } else {
                    return Unmanaged.passRetained(returned)
                }
            }
            return nil
        }

        // For any other event type, pass through
        return Unmanaged.passUnretained(event)
    }
}
