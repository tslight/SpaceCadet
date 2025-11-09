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

    init(remapHandler: @escaping Handler) {
        self.handler = remapHandler
    }

    func start() throws {
        // Note: kCGHIDEventTap intercepts at the HID level
        let mask =
            (1 << CGEventType.keyDown.rawValue | 1 << CGEventType.keyUp.rawValue | 1
                << CGEventType.flagsChanged.rawValue)

        guard
            let tap = CGEvent.tapCreate(
                tap: .cghidEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: CGEventMask(mask),
                callback: { _, type, event, refcon in
                    guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                    let mySelf = Unmanaged<EventTap>.fromOpaque(refcon).takeUnretainedValue()

                    // Re-enable tap if disabled by timeout
                    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                        if let liveTap = mySelf.tap {
                            CGEvent.tapEnable(tap: liveTap, enable: true)
                        }
                        return Unmanaged.passUnretained(event)
                    }

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
                },
                userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
            )
        else {
            throw EventTapError.cannotCreateTap
        }

        guard let rls = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            throw EventTapError.cannotCreateRunLoopSource
        }

        self.tap = tap
        self.runLoopSource = rls

        CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
}
